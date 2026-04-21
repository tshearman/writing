{-# LANGUAGE OverloadedStrings #-}

module SSG.Config
  ( postsDir,
    staticDir,
    outputDir,
    markdownExt,
    htmlExt,
    frontmatterDelimiter,
    devServerPort,
    rebuildDebounceMs,
    siteTitle,
    haskellPreamblePath,
    pythonPreamblePath,
  )
where

import Data.Text (Text)

outputDir :: FilePath
outputDir = "_site"

postsDir :: FilePath
postsDir = "posts"

staticDir :: FilePath
staticDir = "static"

markdownExt :: String
markdownExt = ".md"

htmlExt :: String
htmlExt = ".html"

frontmatterDelimiter :: Text
frontmatterDelimiter = "---\n"

devServerPort :: Int
devServerPort = 8000

rebuildDebounceMs :: Int
rebuildDebounceMs = 1000

siteTitle :: String
siteTitle = "writing"

haskellPreamblePath :: FilePath
haskellPreamblePath = "config/haskell-preamble.hs"

pythonPreamblePath :: FilePath
pythonPreamblePath = "config/python-preamble.py"
