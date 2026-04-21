{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module SSG.Build
  ( BuildMode (..),
    buildSite,
    cleanSite,
    watchAndServe,
    postsDir,
    staticDir,
    outputDir,
  )
where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.Async (concurrently, mapConcurrently)
import Control.Concurrent.STM (atomically, newTVarIO, readTVarIO, writeTVar)
import Control.Monad (forever, unless, void, when)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Logger (MonadLogger, logWarn, runStdoutLoggingT)
import Data.List (isInfixOf)
import Data.Map (Map)
import qualified Data.Map as Map
import qualified Data.Text as T
import qualified Data.Text.Lazy.IO as TLIO
import Lucid (Html, renderText)
import Network.Wai.Application.Static (defaultFileServerSettings, staticApp)
import qualified Network.Wai.Handler.Warp as Warp
import SSG.CodeValidator (ValidationError (..), ValidationResult (..), validatePost)
import SSG.Config (devServerPort, htmlExt, markdownExt, outputDir, postsDir, rebuildDebounceMs, staticDir)
import Utils.Log (handleProcessResult, logDim, logError, logRebuild, logSuccess, timed)
import SSG.Post (ParseError, Post (..), byDateDesc, loadPost, sorted)
import qualified SSG.Post as Post
import Site.Pages.Archive (renderArchivePage)
import Site.Pages.Home (renderHomePage)
import Site.Pages.Post (renderPostPage)
import Site.Pages.Search (renderSearchPage)
import System.Directory
  ( createDirectoryIfMissing,
    doesDirectoryExist,
    getCurrentDirectory,
    listDirectory,
    removeDirectoryRecursive,
  )
import System.FSNotify (eventPath, watchTree, withManager)
import System.FilePath (takeExtension, (</>))
import System.Process (callProcess, readProcessWithExitCode)
import Utils.FileSystem (copyDir, copyPath)

data BuildMode = ProductionMode | DevelopmentMode
  deriving (Eq)

data PostResult
  = PostSuccess Post [ValidationResult]
  | PostFailure ParseError
  | PostSkipped

processPost :: BuildMode -> FilePath -> IO PostResult
processPost mode path = do
  result <- loadPost path
  case result of
    Left err -> pure (PostFailure err)
    Right post -> do
      if postDraft post && mode == ProductionMode
        then pure PostSkipped
        else do
          (valResults, html) <-
            concurrently
              (validatePost path (postBodyLineOffset post) (postBody post))
              (pure (renderPostPage post))
          let outPath = outputDir </> postsDir </> T.unpack (Post.postSlug post) ++ htmlExt
          writeHtml outPath html
          pure (PostSuccess post valResults)

partitionResults :: [PostResult] -> ([ParseError], [Post], [ValidationResult])
partitionResults = foldMap toTriple
  where
    toTriple (PostFailure err) = ([err], [], [])
    toTriple (PostSuccess post valResults) = ([], [post], valResults)
    toTriple PostSkipped = ([], [], [])

buildSite :: (MonadLogger m, MonadIO m) => BuildMode -> m ()
buildSite mode = do
  timed "Building site" $ do
    liftIO $ createDirectoryIfMissing True (outputDir </> postsDir)
    (posts, validationErrors) <- processPosts mode
    reportErrors mode validationErrors
    writePages $ collectPosts posts
    copyStatic
    copyPostAssets
  buildJS
  when (mode == ProductionMode) runPagefind

processPosts :: (MonadLogger m, MonadIO m) => BuildMode -> m ([Post], [ValidationError])
processPosts mode = do
  files <- liftIO $ listDirectory postsDir
  let paths = map (postsDir </>) $ filter ((== markdownExt) . takeExtension) files
  logDim $ "  Found " ++ show (length paths) ++ " post(s)"
  results <- liftIO $ mapConcurrently (processPost mode) paths
  let (parseErrors, posts, validationResults) = partitionResults results
      (blockCount, blockStats, allErrors) = aggregateValidationStats validationResults
  mapM_ (logError . show) parseErrors
  displayValidationSummary blockCount blockStats allErrors
  pure (posts, allErrors)

reportErrors :: (MonadLogger m, MonadIO m) => BuildMode -> [ValidationError] -> m ()
reportErrors mode errors = unless (null errors) $ do
  mapM_ ($(logWarn) . T.pack . show) errors
  when (mode == ProductionMode) $
    error "Build failed: code validation errors"

collectPosts :: [Post] -> Post.Sorted Post
collectPosts = sorted byDateDesc

writePages :: (MonadIO m) => Post.Sorted Post -> m ()
writePages posts = liftIO $ do
  writeHtml (outputDir </> "index" ++ htmlExt) (renderHomePage posts)
  writeHtml (outputDir </> "archive" ++ htmlExt) (renderArchivePage posts)
  writeHtml (outputDir </> "search" ++ htmlExt) renderSearchPage

aggregateValidationStats :: [ValidationResult] -> (Int, Map T.Text (Int, Int), [ValidationError])
aggregateValidationStats results = (length results, langStats, allErrors)
  where
    allErrors = [err | BlockFailure err <- results]
    langStats = foldr countResult Map.empty results
    countResult (BlockSuccess lang) = Map.insertWith addPair lang (1, 0)
    countResult (BlockFailure err) = Map.insertWith addPair (errorLanguage err) (0, 1)
    addPair (a, b) (c, d) = (a + c, b + d)

displayValidationSummary :: (MonadIO m) => Int -> Map T.Text (Int, Int) -> [ValidationError] -> m ()
displayValidationSummary 0 _ _ = pure ()
displayValidationSummary total langStats allErrors = do
  logDim $ "  Found " ++ show total ++ " code block(s)"
  mapM_ (logDim . formatLang) (Map.toList langStats)
  unless (null allErrors) $
    logError $
      show (length allErrors) ++ " code block(s) failed validation"
  where
    formatLang (lang, (passed, failed)) =
      "    " ++ T.unpack lang ++ ": " ++ show passed ++ " passed, " ++ show failed ++ " failed"

writeHtml :: FilePath -> Html () -> IO ()
writeHtml path html = TLIO.writeFile path (renderText html)

copyStatic :: (MonadLogger m, MonadIO m) => m ()
copyStatic = do
  exists <- liftIO $ doesDirectoryExist staticDir
  when exists $ copyDir staticDir outputDir

copyPostAssets :: (MonadLogger m, MonadIO m) => m ()
copyPostAssets = do
  files <- liftIO $ listDirectory postsDir
  let assets = filter ((/= markdownExt) . takeExtension) files
  mapM_ (copyPath postsDir (outputDir </> postsDir)) assets

cleanSite :: (MonadLogger m, MonadIO m) => m ()
cleanSite = do
  exists <- liftIO $ doesDirectoryExist outputDir
  if exists
    then do
      liftIO $ removeDirectoryRecursive outputDir
      logSuccess "Cleaned _site/"
    else logDim "_site/ does not exist"

runPagefind :: (MonadLogger m, MonadIO m) => m ()
runPagefind = timed "Indexing for search" $ do
  result <-
    liftIO $
      readProcessWithExitCode
        "pagefind"
        [ "--site",
          outputDir
        ]
        ""
  handleProcessResult "pagefind" result

buildJS :: (MonadLogger m, MonadIO m) => m ()
buildJS = timed "Building JavaScript" $ do
  liftIO $ callProcess "npm" ["install", "--prefix", "js", "--silent"]
  result <-
    liftIO $
      readProcessWithExitCode
        "esbuild"
        [ "js/src/index.jsx",
          "--bundle",
          "--format=esm",
          "--jsx=automatic",
          "--jsx-import-source=preact",
          "--outfile=" ++ (staticDir </> "js" </> "search.js")
        ]
        ""
  handleProcessResult "esbuild" result

watchAndServe :: (MonadLogger m, MonadIO m) => Bool -> m ()
watchAndServe withSearch = do
  buildSite DevelopmentMode
  when withSearch runPagefind
  cwd <- liftIO getCurrentDirectory

  dirty <- liftIO $ newTVarIO False
  logSuccess $ "Watching for changes on http://localhost:" ++ show devServerPort

  liftIO $ withManager $ \mgr -> do
    let markDirty _ = atomically $ writeTVar dirty True
        notBuildOutput e = not $ (staticDir </> "js") `isInfixOf` eventPath e

    void $ watchTree mgr (cwd </> postsDir) (const True) markDirty
    void $ watchTree mgr (cwd </> staticDir) notBuildOutput markDirty
    void $ watchTree mgr (cwd </> "js" </> "src") (const True) markDirty

    void $ forkIO $ forever $ do
      threadDelay (rebuildDebounceMs * 1000)
      isDirty <- readTVarIO dirty
      when isDirty $ do
        atomically $ writeTVar dirty False
        runStdoutLoggingT $ do
          logRebuild "Rebuilding..."
          buildSite DevelopmentMode
          when withSearch runPagefind

    let settings = Warp.setPort devServerPort Warp.defaultSettings
    Warp.runSettings settings $
      staticApp (defaultFileServerSettings outputDir)
