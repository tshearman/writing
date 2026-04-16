{-# LANGUAGE OverloadedStrings #-}

module SSG.Build
  ( buildSite
  , cleanSite
  ) where

import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.IO as TLIO
import Lucid (Html, renderText)
import SSG.Post (Post (..), loadPosts)
import Site.Pages.Home (renderHomePage)
import Site.Pages.Post (renderPostPage)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist,
                         listDirectory, removeDirectoryRecursive, copyFile)
import System.FilePath ((</>), takeFileName)

outputDir :: FilePath
outputDir = "_site"

buildSite :: IO ()
buildSite = do
  putStrLn "Building site..."
  createDirectoryIfMissing True (outputDir </> "posts")

  posts <- loadPosts "posts"
  putStrLn $ "  Found " ++ show (length posts) ++ " post(s)"

  mapM_ writePost posts
  writeHtml (outputDir </> "index.html") (renderHomePage posts)

  copyStatic
  putStrLn "  Done."

writePost :: Post -> IO ()
writePost post = do
  let path = outputDir </> "posts" </> TL.unpack (TL.fromStrict (postSlug post)) ++ ".html"
  writeHtml path (renderPostPage post)
  putStrLn $ "  Wrote " ++ path

writeHtml :: FilePath -> Html () -> IO ()
writeHtml path html = TLIO.writeFile path (renderText html)

copyStatic :: IO ()
copyStatic = do
  exists <- doesDirectoryExist "static"
  if exists
    then copyDir "static" outputDir
    else pure ()

copyDir :: FilePath -> FilePath -> IO ()
copyDir src dst = do
  entries <- listDirectory src
  mapM_ (copyEntry src dst) entries

copyEntry :: FilePath -> FilePath -> FilePath -> IO ()
copyEntry src dst name = do
  let srcPath = src </> name
      dstPath = dst </> name
  isDir <- doesDirectoryExist srcPath
  if isDir
    then do
      createDirectoryIfMissing True dstPath
      copyDir srcPath dstPath
    else copyFile srcPath dstPath

cleanSite :: IO ()
cleanSite = do
  exists <- doesDirectoryExist outputDir
  if exists
    then do
      removeDirectoryRecursive outputDir
      putStrLn "Cleaned _site/"
    else putStrLn "_site/ does not exist"
