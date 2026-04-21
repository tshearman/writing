{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}

module SSG.CodeValidator
  ( ValidationError (..),
    ValidationResult (..),
    validatePost,
  )
where

import Control.Concurrent.Async (mapConcurrently)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import SSG.Config (haskellPreamblePath, pythonPreamblePath)
import System.Directory (doesFileExist)
import System.Exit (ExitCode (..))
import System.IO (hClose)
import System.IO.Temp (withSystemTempFile)
import System.Process (readProcessWithExitCode)
import Text.Pandoc.Definition (Block (..), Pandoc (..))
import Text.Pandoc.Walk (query)
import Text.Read (readMaybe)
import Text.Regex.TDFA ((=~))

data ValidationError = ValidationError
  { errorPostFile :: Text,
    errorLine :: Maybe Int,
    errorLanguage :: Text,
    errorCode :: Text,
    errorMessage :: Text
  }

instance Show ValidationError where
  show :: ValidationError -> String
  show err =
    T.unpack $
      "[" <> fileLocation <> "] [" <> errorLanguage err <> "] " <> errorMessage err
    where
      fileLocation = case errorLine err of
        Just line -> errorPostFile err <> ":" <> T.pack (show line)
        Nothing -> errorPostFile err

data ValidationResult
  = BlockSuccess Text
  | BlockFailure ValidationError
  deriving (Show)

data SourceBlock = SourceBlock
  { blockLang :: Text,
    blockCode :: Text,
    blockLine :: Maybe Int
  }

type Validator = Text -> IO (Either Text ())

data LangConfig = LangConfig
  { langPreamble :: Maybe Text,
    langValidator :: Validator
  }

loadLangConfigs :: IO (Map Text LangConfig)
loadLangConfigs = do
  haskellPre <- loadPreamble haskellPreamblePath
  pythonPre <- loadPreamble pythonPreamblePath
  pure $
    Map.fromList
      [ ("haskell", LangConfig haskellPre validateHaskellCode),
        ("python", LangConfig pythonPre validatePythonCode)
      ]

validatePost :: FilePath -> Int -> Pandoc -> IO [ValidationResult]
validatePost file lineOffset doc = do
  configs <- loadLangConfigs
  let blocks = extractSourceBlocks doc
      adjustLine = fmap (+ lineOffset)
      supported = mapMaybe (\b -> (,b) <$> Map.lookup (blockLang b) configs) blocks
  mapConcurrently (runValidator file adjustLine) supported

runValidator :: FilePath -> (Maybe Int -> Maybe Int) -> (LangConfig, SourceBlock) -> IO ValidationResult
runValidator file adj (cfg, block) = do
  result <- langValidator cfg $ attachPreamble (langPreamble cfg) (blockCode block)
  pure $ case result of
    Right () -> BlockSuccess (blockLang block)
    Left msg ->
      BlockFailure
        ValidationError
          { errorPostFile = T.pack file,
            errorLine = adj (blockLine block),
            errorLanguage = blockLang block,
            errorCode = blockCode block,
            errorMessage = msg
          }

loadPreamble :: FilePath -> IO (Maybe Text)
loadPreamble path = do
  exists <- doesFileExist path
  if exists
    then Just <$> TIO.readFile path
    else pure Nothing

extractSourceBlocks :: Pandoc -> [SourceBlock]
extractSourceBlocks = query getSourceBlock
  where
    getSourceBlock (CodeBlock (_, lang : _, kvs) code) = [SourceBlock lang code (extractLineNumber kvs)]
    getSourceBlock _ = []
    extractLineNumber kvs =
      readMaybe . T.unpack . T.takeWhile (/= ':') =<< lookup "data-pos" kvs

attachPreamble :: Maybe Text -> Text -> Text
attachPreamble Nothing code = code
attachPreamble (Just pre) code = pre <> "\n\n" <> code

validatePythonCode :: Validator
validatePythonCode code = runCommand "python" ["-c", T.unpack code]

validateHaskellCode :: Validator
validateHaskellCode code = do
  let hasMain = T.unpack code =~ ("(^|\\n)[ \\t]*main[ \\t]*(::}=)" :: String)
  withSystemTempFile "code.hs" $ \tempFile handle -> do
    TIO.hPutStr handle code
    hClose handle
    if hasMain
      then runCommand "runghc" [tempFile]
      else runCommand "ghc" ["-fno-code", "-v0", tempFile]

runCommand :: String -> [String] -> IO (Either Text ())
runCommand cmd args = do
  (exitCode, stdout, stderr) <- readProcessWithExitCode cmd args ""
  pure $ case exitCode of
    ExitSuccess -> Right ()
    ExitFailure _ -> Left (T.pack $ stdout ++ stderr)
