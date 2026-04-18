{-# LANGUAGE OverloadedStrings #-}

module SSG.CodeValidator
  ( validatePost,
  )
where

import Control.Monad (forM)
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

data CodeBlockError = CodeBlockError
  { errorLanguage :: Text,
    errorCode :: Text,
    errorMessage :: Text
  }
  deriving (Show)

-- | Extract all code blocks from a Pandoc document
extractCodeBlocks :: Pandoc -> [(Text, Text)]
extractCodeBlocks = query getCodeBlock
  where
    getCodeBlock :: Block -> [(Text, Text)]
    getCodeBlock (CodeBlock (_, classes, _) code) =
      case classes of
        (lang : _) -> [(lang, code)]
        [] -> []
    getCodeBlock _ = []

-- | Load preamble if it exists
loadPreamble :: IO (Maybe Text)
loadPreamble = do
  exists <- doesFileExist preamblePath
  if exists
    then Just <$> TIO.readFile preamblePath
    else pure Nothing

-- | Validate all Haskell code blocks in a post
-- Returns Nothing on success, or Just errorMessage on failure
validatePost :: FilePath -> Pandoc -> IO (Maybe String)
validatePost path doc = do
  preamble <- loadPreamble
  let codeBlocks = extractCodeBlocks doc
      haskellBlocks = filter (\(lang, _) -> lang == "haskell") codeBlocks
  results <- forM haskellBlocks $ \(_, code) ->
    validateHaskellCode preamble code
  let errors = [err | Just err <- results]
  pure $ if null errors
    then Nothing
    else Just (formatErrors path errors)

formatErrors :: FilePath -> [CodeBlockError] -> String
formatErrors path errors =
  "Code validation failed in " ++ path ++ ":\n"
    ++ unlines (map formatError errors)
  where
    formatError err =
      "  [" ++ T.unpack (errorLanguage err) ++ "] "
        ++ T.unpack (errorMessage err)

-- | Validate a single Haskell code block
validateHaskellCode :: Maybe Text -> Text -> IO (Maybe CodeBlockError)
validateHaskellCode preamble code = do
  let fullCode = case preamble of
        Nothing -> code
        Just pre -> pre <> "\n\n" <> code
      hasMain = T.isInfixOf "main" code

  -- withSystemTempFile ensures cleanup even if an exception occurs
  withSystemTempFile "code-check.hs" $ \tempFile handle -> do
    TIO.hPutStr handle fullCode
    hClose handle

    -- Type-check only (module CodeCheck in preamble avoids main requirement)
    (exitCode, stdout, stderr) <- readProcessWithExitCode
      "ghc"
      ["-fno-code", "-v0", tempFile]
      ""

    case exitCode of
      ExitSuccess ->
        -- If compilation succeeds and there's a main function, try to run it
        if hasMain
          then runCode fullCode
          else pure Nothing -- Just a function definition, compilation is enough
      ExitFailure _ ->
        pure $ Just $ CodeBlockError
          { errorLanguage = "haskell",
            errorCode = code,
            errorMessage = T.pack (stdout ++ stderr)
          }

-- | Try to run Haskell code using runhaskell
runCode :: Text -> IO (Maybe CodeBlockError)
runCode code =
  withSystemTempFile "code-run.hs" $ \tempFile handle -> do
    TIO.hPutStr handle code
    hClose handle

    (exitCode, stdout, stderr) <- readProcessWithExitCode
      "runhaskell"
      [tempFile]
      ""

    case exitCode of
      ExitSuccess -> pure Nothing
      ExitFailure _ ->
        pure $ Just $ CodeBlockError
          { errorLanguage = "haskell",
            errorCode = code,
            errorMessage = T.pack ("Runtime error: " ++ stdout ++ stderr)
          }
