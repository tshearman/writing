{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad.Logger (runStdoutLoggingT)
import Options.Applicative
import SSG.Build (BuildMode (..), buildSite, cleanSite, watchAndServe)

data Command = Build | Clean | Watch

commandParser :: Parser Command
commandParser =
  subparser
    ( command "build" (info (pure Build) (progDesc "Build site to _site/"))
        <> command "clean" (info (pure Clean) (progDesc "Remove _site/"))
        <> command "watch" (info (pure Watch) (progDesc "Build, watch for changes, serve on localhost:8000"))
    )

main :: IO ()
main = do
  cmd <-
    execParser
      ( info
          (commandParser <**> helper)
          (fullDesc <> progDesc "Custom Haskell static site generator")
      )
  case cmd of
    Build -> runStdoutLoggingT (buildSite ProductionMode)
    Clean -> runStdoutLoggingT cleanSite
    Watch -> runStdoutLoggingT watchAndServe
