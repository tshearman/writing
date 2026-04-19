{-# LANGUAGE OverloadedStrings #-}

module SSG.CodeValidator
  ( ValidationError (..),
    validatePost,
    formatValidationError,
  )
where

import Control.Concurrent.Async (mapConcurrently)
import qualified Data.Maybe
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory (doesFileExist)
import System.Exit (ExitCode (..))
import System.IO (hClose)
import System.IO.Temp (withSystemTempFile)
import System.Process (readProcessWithExitCode)
import Text.Pandoc.Definition (Block (..), Pandoc (..))
import Text.Pandoc.Walk (query)

preamblePath :: FilePath
preamblePath = "haskell-preamble.hs"

data ValidationError = ValidationError
  { errorLanguage :: Text,
    errorCode :: Text,
    errorMessage :: Text
  }
  deriving (Show)

formatValidationError :: ValidationError -> Text
formatValidationError err =
  "[" <> errorLanguage err <> "] " <> errorMessage err

extractCodeBlocks :: Pandoc -> [(Text, Text)]
extractCodeBlocks = query getCodeBlock
  where
    getCodeBlock :: Block -> [(Text, Text)]
    getCodeBlock (CodeBlock (_, classes, _) code) =
      case classes of
        (lang : _) -> [(lang, code)]
        [] -> []
    getCodeBlock _ = []

loadPreamble :: IO (Maybe Text)
loadPreamble = do
  exists <- doesFileExist preamblePath
  if exists
    then Just <$> TIO.readFile preamblePath
    else pure Nothing

validatePost :: Pandoc -> IO [ValidationError]
validatePost doc = do
  preamble <- loadPreamble
  let codeBlocks = extractCodeBlocks doc
      haskellBlocks = filter (\(lang, _) -> lang == "haskell") codeBlocks
  results <- mapConcurrently (validateHaskellCode preamble . snd) haskellBlocks
  pure (Data.Maybe.catMaybes results)

validateHaskellCode :: Maybe Text -> Text -> IO (Maybe ValidationError)
validateHaskellCode preamble code = do
  let fullCode = case preamble of
        Nothing -> code
        Just pre -> pre <> "\n\n" <> code
      hasMain = T.isInfixOf "main" code

  withSystemTempFile "code-check.hs" $ \tempFile handle -> do
    TIO.hPutStr handle fullCode
    hClose handle

    (exitCode, stdout, stderr) <-
      readProcessWithExitCode
        "ghc"
        ["-fno-code", "-v0", tempFile]
        ""

    case exitCode of
      ExitSuccess ->
        if hasMain
          then runCode fullCode
          else pure Nothing
      ExitFailure _ ->
        pure $
          Just $
            ValidationError
              { errorLanguage = "haskell",
                errorCode = code,
                errorMessage = T.pack (stdout ++ stderr)
              }

runCode :: Text -> IO (Maybe ValidationError)
runCode code =
  withSystemTempFile "code-run.hs" $ \tempFile handle -> do
    TIO.hPutStr handle code
    hClose handle

    (exitCode, stdout, stderr) <-
      readProcessWithExitCode
        "runhaskell"
        [tempFile]
        ""

    case exitCode of
      ExitSuccess -> pure Nothing
      ExitFailure _ ->
        pure $
          Just $
            ValidationError
              { errorLanguage = "haskell",
                errorCode = code,
                errorMessage = T.pack ("Runtime error: " ++ stdout ++ stderr)
              }
