{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module SSG.Build
  ( buildSite,
    cleanSite,
    watchAndServe,
    postsDir,
    staticDir,
    outputDir,
  )
where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (atomically, newTVarIO, readTVarIO, writeTVar)
import Control.Monad (forever, void, when)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Logger (MonadLogger, logInfo, runStdoutLoggingT)
import qualified Data.Text as T
import qualified Data.Text.Lazy.IO as TLIO
import Lucid (Html, renderText)
import Network.Wai.Application.Static (defaultFileServerSettings, staticApp)
import qualified Network.Wai.Handler.Warp as Warp
import SSG.Config (devServerPort, homepageFile, htmlExt, outputDir, postsDir, rebuildDebounceMs, staticDir)
import SSG.Post (Post (..), loadPosts)
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
import System.FilePath ((</>))

buildSite :: (MonadLogger m, MonadIO m) => m ()
buildSite = do
  $(logInfo) "Building site..."
  liftIO $ createDirectoryIfMissing True (outputDir </> postsDir)

  posts <- liftIO $ loadPosts postsDir
  $(logInfo) $ "Found " <> T.pack (show (length posts)) <> " post(s)"

  mapM_ writePost posts
  liftIO $ writeHtml (outputDir </> homepageFile) (renderHomePage posts)
  liftIO $ writeHtml (outputDir </> "archive" ++ htmlExt) (renderArchivePage posts)

  copyStatic
  $(logInfo) "Done."

writePost :: (MonadLogger m, MonadIO m) => Post -> m ()
writePost post = do
  let path = outputDir </> postsDir </> T.unpack (postSlug post) ++ htmlExt
  liftIO $ writeHtml path (renderPostPage post)
  $(logInfo) $ "Wrote " <> T.pack path

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
  buildSite
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
          buildSite

    let settings = Warp.setPort devServerPort Warp.defaultSettings
    Warp.runSettings settings $
      staticApp (defaultFileServerSettings outputDir)
