{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Options.Applicative
import SSG.App (BuildMode (..), runApp)
import SSG.Build (buildSite, cleanSite, watchAndServe)

data Command
  = Build
  | Clean
  | Watch {_withSearch :: Bool}

commandParser :: Parser Command
commandParser =
  subparser
    ( command "build" (info (pure Build) (progDesc "Build site + search index"))
        <> command "clean" (info (pure Clean) (progDesc "Remove _site/"))
        <> command "watch" (info watchParser (progDesc "Watch & serve on localhost:8000"))
    )

watchParser :: Parser Command
watchParser =
  Watch
    <$> switch
      ( long "search"
          <> help "Run pagefind on each rebuild (slower but search works locally)"
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
    Build -> runApp ProductionMode True buildSite
    Clean -> runApp ProductionMode False cleanSite
    Watch search -> runApp DevelopmentMode search watchAndServe
