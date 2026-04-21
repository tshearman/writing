{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module SSG.Post
  ( Post (..),
    ParseError (..),
    Sorted,
    filterDrafts,
    loadPost,
    groupPostsByYear,
    postUrl,
    sorted,
    byDateDesc,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (except, runExceptT)
import Data.Aeson (FromJSON (..), withObject, (.!=), (.:), (.:?))
import Data.Bifunctor (first)
import Data.List (sortBy)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.IO as TIO
import Data.Time (Day)
import Data.Yaml (decodeEither')
import GHC.Generics (Generic)
import SSG.Config (frontmatterDelimiter, htmlExt, postsDir)
import System.FilePath (takeBaseName)
import Text.Pandoc (Pandoc, PandocError, def, extensionsFromList, readCommonMark, runPure)
import Text.Pandoc.Extensions (Extension (..))
import Text.Pandoc.Options (ReaderOptions (..))

data Post = Post
  { postTitle :: Text,
    postDescription :: Maybe Text,
    postDate :: Day,
    postTags :: [Text],
    postDraft :: Bool,
    postFeatured :: Bool,
    postSlug :: Text,
    postBody :: Pandoc,
    postBodyLineOffset :: Int
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

newtype Sorted a = Sorted [a]
  deriving (Foldable)

class Dated a where
  getDate :: a -> Day

instance Dated Post where
  getDate = postDate

sorted :: (a -> a -> Ordering) -> [a] -> Sorted a
sorted cmp = Sorted . sortBy cmp

byDateDesc :: (Dated a) => a -> a -> Ordering
byDateDesc a b = compare (getDate b) (getDate a)

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

commonmarkReaderOpts :: ReaderOptions
commonmarkReaderOpts =
  def
    { readerExtensions =
        extensionsFromList
          [ Ext_sourcepos,
            Ext_fenced_code_blocks,
            Ext_fenced_code_attributes,
            Ext_backtick_code_blocks,
            Ext_tex_math_dollars,
            Ext_strikeout,
            Ext_autolink_bare_uris,
            Ext_pipe_tables,
            Ext_task_lists,
            Ext_smart
          ]
    }

loadPost :: FilePath -> IO (Either ParseError Post)
loadPost path = runExceptT $ do
  content <- liftIO $ TIO.readFile path
  let slug = T.pack (takeBaseName path)

  (fm, body) <- except $ first FrontmatterError $ parseFrontMatter content
  pandoc <- except $ first MarkdownError $ runPure (readCommonMark commonmarkReaderOpts body)

  let bodyOffset = length (T.lines content) - length (T.lines body)

  pure
    Post
      { postTitle = fmTitle fm,
        postDescription = fmDescription fm,
        postDate = fmPubDate fm,
        postTags = fmTags fm,
        postDraft = fmDraft fm,
        postFeatured = fmFeatured fm,
        postSlug = slug,
        postBody = pandoc,
        postBodyLineOffset = bodyOffset
      }

groupPostsByYear :: (Day -> Integer) -> Sorted Post -> [(Integer, Sorted Post)]
groupPostsByYear getYear (Sorted posts) =
  Map.toDescList $ Map.fromListWith combine yearAssocs
  where
    yearAssocs = [(getYear (getDate p), sorted byDateDesc [p]) | p <- posts]
    combine (Sorted xs) (Sorted ys) = sorted byDateDesc (xs ++ ys)