{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module SSG.Post
  ( Post (..),
    ParseError (..),
    SortedPosts,
    getPosts,
    sortPostsBy,
    byDateDesc,
    filterDrafts,
    loadPost,
    groupPostsByYear,
    postUrl,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (except, runExceptT)
import Data.Aeson (FromJSON (..), withObject, (.!=), (.:), (.:?))
import Data.Bifunctor (first)
import Data.List (sortBy)
import qualified Data.Map.Strict as Map
import Data.Ord (Down (..))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.IO as TIO
import Data.Time (Day)
import Data.Yaml (decodeEither')
import GHC.Generics (Generic)
import SSG.Config (frontmatterDelimiter, htmlExt, postsDir)
import System.FilePath (takeBaseName)
import Text.Pandoc (Pandoc, PandocError, def, readMarkdown, runPure)
import Text.Pandoc.Extensions (Extension (..), enableExtension, githubMarkdownExtensions)
import Text.Pandoc.Options (ReaderOptions (..))

data Post = Post
  { postTitle :: Text,
    postDescription :: Maybe Text,
    postDate :: Day,
    postTags :: [Text],
    postDraft :: Bool,
    postFeatured :: Bool,
    postSlug :: Text,
    postBody :: Pandoc
  }
  deriving (Show, Generic)

data FrontMatter = FrontMatter
  { fmTitle :: Text,
    fmDescription :: Maybe Text,
    fmPubDate :: Day,
    fmTags :: [Text],
    fmDraft :: Bool,
    fmFeatured :: Bool
  }
  deriving (Show, Generic)

data ParseError
  = FrontmatterError String
  | MarkdownError PandocError
  deriving (Show)

newtype SortedPosts = SortedPosts [Post]

getPosts :: SortedPosts -> [Post]
getPosts (SortedPosts posts) = posts

sortPostsBy :: (Post -> Post -> Ordering) -> [Post] -> SortedPosts
sortPostsBy cmp = SortedPosts . sortBy cmp

byDateDesc :: Post -> Post -> Ordering
byDateDesc a b = compare (Down (postDate a)) (Down (postDate b))

filterDrafts :: [Post] -> [Post]
filterDrafts = filter (not . postDraft)

postUrl :: Post -> Text
postUrl post = "/" <> T.pack postsDir <> "/" <> postSlug post <> T.pack htmlExt

instance FromJSON FrontMatter where
  parseJSON = withObject "FrontMatter" $ \o ->
    FrontMatter
      <$> o .: "title"
      <*> o .:? "description"
      <*> o .: "pubDate"
      <*> o .:? "tags" .!= []
      <*> o .:? "draft" .!= False
      <*> o .:? "featured" .!= False

parseFrontMatter :: Text -> Either String (FrontMatter, Text)
parseFrontMatter content =
  case extractYamlAndBody content of
    Nothing -> Left $ T.unpack $ "No frontmatter found (expected " <> frontmatterDelimiter <> " delimiters)"
    Just (yaml, body) -> do
      fm <- decodeYaml yaml
      pure (fm, body)

extractYamlAndBody :: Text -> Maybe (Text, Text)
extractYamlAndBody content
  | ("" : yaml : rest) <- T.splitOn frontmatterDelimiter content = Just (yaml, T.intercalate frontmatterDelimiter rest)
  | otherwise = Nothing

decodeYaml :: Text -> Either String FrontMatter
decodeYaml yaml = first show $ decodeEither' (TE.encodeUtf8 yaml)

markdownReaderOpts :: ReaderOptions
markdownReaderOpts =
  def
    { readerExtensions =
        enableExtension Ext_tex_math_dollars githubMarkdownExtensions
    }

loadPost :: FilePath -> IO (Either ParseError Post)
loadPost path = runExceptT $ do
  content <- liftIO $ TIO.readFile path
  let slug = T.pack (takeBaseName path)

  (fm, body) <- except $ first FrontmatterError $ parseFrontMatter content
  pandoc <- except $ first MarkdownError $ runPure (readMarkdown markdownReaderOpts body)

  pure
    Post
      { postTitle = fmTitle fm,
        postDescription = fmDescription fm,
        postDate = fmPubDate fm,
        postTags = fmTags fm,
        postDraft = fmDraft fm,
        postFeatured = fmFeatured fm,
        postSlug = slug,
        postBody = pandoc
      }

groupPostsByYear :: (Day -> Integer) -> SortedPosts -> [(Integer, [Post])]
groupPostsByYear getYear (SortedPosts posts) =
  Map.toDescList $ Map.fromListWith (flip (++)) yearAssocs
  where
    yearAssocs = [(getYear (postDate p), [p]) | p <- posts]
