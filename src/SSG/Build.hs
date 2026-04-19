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
import Control.Monad.Logger (MonadLogger, logInfo, logWarn, runStdoutLoggingT)
import qualified Data.Text as T
import qualified Data.Text.Lazy.IO as TLIO
import Lucid (Html, renderText)
import Network.Wai.Application.Static (defaultFileServerSettings, staticApp)
import qualified Network.Wai.Handler.Warp as Warp
import SSG.CodeValidator (ValidationError, formatValidationError, validatePost)
import SSG.Config (devServerPort, homepageFile, htmlExt, markdownExt, outputDir, postsDir, rebuildDebounceMs, staticDir)
import SSG.Post (ParseError, Post (..), byDateDesc, filterDrafts, getPosts, loadPost, sortPostsBy)
import Site.Pages.Archive (renderArchivePage)
import Site.Pages.Home (renderHomePage)
import Site.Pages.Post (renderPostPage)
import System.Directory
  ( copyFile,
    createDirectoryIfMissing,
    doesDirectoryExist,
    getCurrentDirectory,
    listDirectory,
    removeDirectoryRecursive,
  )
import System.FSNotify (watchTree, withManager)
import System.FilePath (takeExtension, (</>))

data BuildMode = ProductionMode | DevelopmentMode
  deriving (Eq)

data PostResult
  = PostSuccess Post [ValidationError]
  | PostFailure ParseError

processPost :: BuildMode -> FilePath -> IO PostResult
processPost mode path = do
  result <- loadPost path
  case result of
    Left err -> pure (PostFailure err)
    Right post -> do
      if postDraft post && mode == ProductionMode
        then pure (PostSuccess post [])
        else do
          (errors, html) <-
            concurrently
              (validatePost (postBody post))
              (pure (renderPostPage post))
          let outPath = outputDir </> postsDir </> T.unpack (postSlug post) ++ htmlExt
          writeHtml outPath html
          pure (PostSuccess post errors)

partitionResults :: [PostResult] -> ([ParseError], [Post], [ValidationError])
partitionResults = foldMap toTriple
  where
    toTriple (PostFailure err) = ([err], [], [])
    toTriple (PostSuccess post errs) = ([], [post], errs)

buildSite :: (MonadLogger m, MonadIO m) => BuildMode -> m ()
buildSite mode = do
  $(logInfo) "Building site..."
  liftIO $ createDirectoryIfMissing True (outputDir </> postsDir)

  files <- liftIO $ listDirectory postsDir
  let mdFiles = filter ((== markdownExt) . takeExtension) files
      paths = map (postsDir </>) mdFiles

  $(logInfo) $ "Found " <> T.pack (show (length paths)) <> " post(s)"

  results <- liftIO $ mapConcurrently (processPost mode) paths
  let (parseErrors, posts, validationErrors) = partitionResults results

  mapM_ ($(logInfo) . T.pack . show) parseErrors

  case mode of
    ProductionMode -> do
      unless (null validationErrors) $ do
        mapM_ ($(logInfo) . formatValidationError) validationErrors
        error "Build failed: code validation errors"
    DevelopmentMode ->
      mapM_ ($(logWarn) . formatValidationError) validationErrors

  let filteredPosts = case mode of
        ProductionMode -> filterDrafts posts
        DevelopmentMode -> posts
      sortedPosts = sortPostsBy byDateDesc filteredPosts
  liftIO $ writeHtml (outputDir </> homepageFile) (renderHomePage (getPosts sortedPosts))
  liftIO $ writeHtml (outputDir </> "archive" ++ htmlExt) (renderArchivePage sortedPosts)

  copyStatic
  $(logInfo) "Done."

writeHtml :: FilePath -> Html () -> IO ()
writeHtml path html = TLIO.writeFile path (renderText html)

copyStatic :: (MonadLogger m, MonadIO m) => m ()
copyStatic = do
  exists <- liftIO $ doesDirectoryExist staticDir
  when exists $ copyDir staticDir outputDir

copyDir :: (MonadLogger m, MonadIO m) => FilePath -> FilePath -> m ()
copyDir src dst = do
  entries <- liftIO $ listDirectory src
  mapM_ (copyEntry src dst) entries

copyEntry :: (MonadLogger m, MonadIO m) => FilePath -> FilePath -> FilePath -> m ()
copyEntry src dst name = do
  let srcPath = src </> name
      dstPath = dst </> name
  isDir <- liftIO $ doesDirectoryExist srcPath
  if isDir
    then do
      liftIO $ createDirectoryIfMissing True dstPath
      copyDir srcPath dstPath
    else liftIO $ copyFile srcPath dstPath

cleanSite :: (MonadLogger m, MonadIO m) => m ()
cleanSite = do
  exists <- liftIO $ doesDirectoryExist outputDir
  if exists
    then do
      liftIO $ removeDirectoryRecursive outputDir
      $(logInfo) "Cleaned _site/"
    else $(logInfo) "_site/ does not exist"

watchAndServe :: (MonadLogger m, MonadIO m) => m ()
watchAndServe = do
  buildSite DevelopmentMode
  cwd <- liftIO getCurrentDirectory

  dirty <- liftIO $ newTVarIO False
  $(logInfo) $ "Watching for changes... Serving on http://localhost:" <> T.pack (show devServerPort)

  liftIO $ withManager $ \mgr -> do
    let markDirty _ = atomically $ writeTVar dirty True

    void $ watchTree mgr (cwd </> postsDir) (const True) markDirty
    void $ watchTree mgr (cwd </> staticDir) (const True) markDirty

    void $ forkIO $ forever $ do
      threadDelay (rebuildDebounceMs * 1000)
      isDirty <- readTVarIO dirty
      when isDirty $ do
        atomically $ writeTVar dirty False
        runStdoutLoggingT $ do
          $(logInfo) "\nRebuild triggered..."
          buildSite DevelopmentMode

    let settings = Warp.setPort devServerPort Warp.defaultSettings
    Warp.runSettings settings $
      staticApp (defaultFileServerSettings outputDir)
