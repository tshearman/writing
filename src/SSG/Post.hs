{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module SSG.Post
  ( Post (..),
    loadPost,
    loadPosts,
    groupPostsByYear,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT (..), except, runExceptT)
import Data.Aeson (FromJSON (..), withObject, (.!=), (.:), (.:?))
import Data.Bifunctor (first)
import Data.Either (partitionEithers)
import Data.List (groupBy, sortOn)
import Data.Ord (Down (..))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.IO as TIO
import Data.Time (Day)
import Data.Yaml (decodeEither')
import GHC.Generics (Generic)
import SSG.CodeValidator (validatePost)
import SSG.Config (frontmatterDelimiter, markdownExt)
import System.Directory (listDirectory)
import System.FilePath (takeBaseName, takeExtension, (</>))
import Text.Pandoc (Pandoc, def, readMarkdown, runPure)
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
  case T.splitOn (T.pack frontmatterDelimiter) content of
    ("" : yaml : rest) ->
      case decodeEither' (TE.encodeUtf8 yaml) of
        Left err -> Left (show err)
        Right fm -> Right (fm, T.intercalate (T.pack frontmatterDelimiter) rest)
    _ -> Left "No frontmatter found (expected --- delimiters)"

markdownReaderOpts :: ReaderOptions
markdownReaderOpts =
  def
    { readerExtensions =
        enableExtension Ext_tex_math_dollars githubMarkdownExtensions
    }

loadPost :: FilePath -> IO (Either String Post)
loadPost path = runExceptT $ do
  content <- liftIO $ TIO.readFile path
  let slug = T.pack (takeBaseName path)

  (fm, body) <- except $ parseFrontMatter content
  pandoc <- except $ first show $ runPure (readMarkdown markdownReaderOpts body)

  validationResult <- liftIO $ validatePost path pandoc
  case validationResult of
    Just err -> except $ Left err
    Nothing ->
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

loadPosts :: FilePath -> IO [Post]
loadPosts dir = do
  files <- listDirectory dir
  results <- mapM (loadPost . (dir </>)) (markdownFiles files)
  let (errors, allPosts) = partitionEithers results
  mapM_ putStrLn errors
  pure (sortedNonDrafts allPosts)
  where
    markdownFiles = filter ((== markdownExt) . takeExtension)
    sortedNonDrafts = sortOn (Down . postDate) . filter (not . postDraft)

-- | Group posts by their publication year
-- Posts must be sorted by date (newest first) for proper grouping
groupPostsByYear :: (Day -> Integer) -> [Post] -> [(Integer, [Post])]
groupPostsByYear getYear posts = map toYearGroup grouped
  where
    postsWithYear = map (\p -> (getYear (postDate p), p)) posts
    grouped = groupBy (\(y1, _) (y2, _) -> y1 == y2) postsWithYear
    toYearGroup [] = error "groupBy never produces empty groups"
    toYearGroup group@((year, _) : _) = (year, map snd group)
