module Utils.FileSystem (copyDir, copyPath) where

import Control.Monad.IO.Class (MonadIO, liftIO)
import System.Directory (copyFile, createDirectoryIfMissing, doesDirectoryExist, listDirectory)
import System.FilePath ((</>))

copyDir :: MonadIO m => FilePath -> FilePath -> m ()
copyDir src dst = do
  entries <- liftIO $ listDirectory src
  mapM_ (copyPath src dst) entries

copyPath :: MonadIO m => FilePath -> FilePath -> FilePath -> m ()
copyPath src dst name = do
  let srcPath = src </> name
      dstPath = dst </> name
  isDir <- liftIO $ doesDirectoryExist srcPath
  if isDir
    then do
      liftIO $ createDirectoryIfMissing True dstPath
      copyDir srcPath dstPath
    else liftIO $ copyFile srcPath dstPath
