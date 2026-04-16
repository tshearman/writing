{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module SSG.Post
  ( Post (..)
  , loadPost
  , loadPosts
  ) where

import Data.Aeson (FromJSON (..), withObject, (.:), (.:?), (.!=))
import Data.List (sortOn)
import Data.Ord (Down (..))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Time (Day)
import GHC.Generics (Generic)
import System.Directory (listDirectory)
import System.FilePath ((</>), takeBaseName, takeExtension)
import Text.Pandoc (Pandoc, def, readMarkdown, runPure)
import qualified Data.ByteString.Char8 as BS
import Data.Yaml (decodeEither')

data Post = Post
  { postTitle       :: Text
  , postDescription :: Maybe Text
  , postAbstract    :: Maybe Text
  , postDate        :: Day
  , postTags        :: [Text]
  , postDraft       :: Bool
  , postFeatured    :: Bool
  , postHeroImage   :: Maybe Text
  , postSlug        :: Text
  , postBody        :: Pandoc
  } deriving (Show, Generic)

data FrontMatter = FrontMatter
  { fmTitle       :: Text
  , fmDescription :: Maybe Text
  , fmAbstract    :: Maybe Text
  , fmPubDate     :: Day
  , fmTags        :: [Text]
  , fmDraft       :: Bool
  , fmFeatured    :: Bool
  , fmHeroImage   :: Maybe Text
  } deriving (Show, Generic)

instance FromJSON FrontMatter where
  parseJSON = withObject "FrontMatter" $ \o -> FrontMatter
    <$> o .:  "title"
    <*> o .:? "description"
    <*> o .:? "abstract"
    <*> o .:  "pubDate"
    <*> o .:? "tags" .!= []
    <*> o .:? "draft" .!= False
    <*> o .:? "featured" .!= False
    <*> o .:? "heroImage"

parseFrontMatter :: Text -> Either String (FrontMatter, Text)
parseFrontMatter content =
  case T.splitOn "---" content of
    ("" : yaml : rest) ->
      case decodeEither' (BS.pack $ T.unpack yaml) of
        Left err   -> Left (show err)
        Right fm   -> Right (fm, T.intercalate "---" rest)
    _ -> Left "No frontmatter found (expected --- delimiters)"

loadPost :: FilePath -> IO (Either String Post)
loadPost path = do
  content <- TIO.readFile path
  let slug = T.pack (takeBaseName path)
  pure $ do
    (fm, body) <- parseFrontMatter content
    pandoc <- case runPure (readMarkdown def body) of
      Left err  -> Left (show err)
      Right doc -> Right doc
    Right Post
      { postTitle       = fmTitle fm
      , postDescription = fmDescription fm
      , postAbstract    = fmAbstract fm
      , postDate        = fmPubDate fm
      , postTags        = fmTags fm
      , postDraft       = fmDraft fm
      , postFeatured    = fmFeatured fm
      , postHeroImage   = fmHeroImage fm
      , postSlug        = slug
      , postBody        = pandoc
      }

loadPosts :: FilePath -> IO [Post]
loadPosts dir = do
  files <- listDirectory dir
  let mdFiles = filter (\f -> takeExtension f == ".md") files
  results <- mapM (loadPost . (dir </>)) mdFiles
  let posts = [p | Right p <- results, not (postDraft p)]
  pure $ sortOn (Down . postDate) posts
