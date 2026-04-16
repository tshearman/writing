{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (newTVarIO, readTVarIO, writeTVar, atomically)
import Control.Monad (forever, void, when)
import qualified Network.Wai.Handler.Warp as Warp
import Network.Wai.Application.Static (staticApp, defaultFileServerSettings)
import Options.Applicative
import SSG.Build (buildSite, cleanSite)
import System.FSNotify (withManager, watchTree)
import System.Directory (getCurrentDirectory)
import System.FilePath ((</>))

data Command = Build | Clean | Watch

commandParser :: Parser Command
commandParser = subparser
  ( command "build" (info (pure Build) (progDesc "Build site to _site/"))
 <> command "clean" (info (pure Clean) (progDesc "Remove _site/"))
 <> command "watch" (info (pure Watch) (progDesc "Build, watch for changes, serve on localhost:8000"))
  )

main :: IO ()
main = do
  cmd <- execParser (info (commandParser <**> helper)
           (fullDesc <> progDesc "Custom Haskell static site generator"))
  case cmd of
    Build -> buildSite
    Clean -> cleanSite
    Watch -> watchAndServe

watchAndServe :: IO ()
watchAndServe = do
  buildSite
  cwd <- getCurrentDirectory

  dirty <- newTVarIO False
  putStrLn "Watching for changes... Serving on http://localhost:8000"

  withManager $ \mgr -> do
    let markDirty _ = atomically $ writeTVar dirty True

    void $ watchTree mgr (cwd </> "posts")  (const True) markDirty
    void $ watchTree mgr (cwd </> "static") (const True) markDirty

    void $ forkIO $ forever $ do
      threadDelay 1000000
      isDirty <- readTVarIO dirty
      when isDirty $ do
        atomically $ writeTVar dirty False
        putStrLn "\nRebuild triggered..."
        buildSite

    let settings = Warp.setPort 8000 Warp.defaultSettings
    Warp.runSettings settings $
      staticApp (defaultFileServerSettings "_site")
