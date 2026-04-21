module Utils.Log
  ( timed,
    log,
    logDim,
    logStep,
    logSuccess,
    logError,
    logRebuild,
    handleProcessResult,
    -- Colors
    green,
    cyan,
    yellow,
    red,
    dim,
    reset,
    -- Symbols
    symStep,
    symSuccess,
    symError,
    symRebuild,
  )
where

import Control.Monad (unless)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Time.Clock (diffUTCTime, getCurrentTime)
import System.Exit (ExitCode (..))
import System.IO (hFlush, stdout)
import Text.Printf (printf)
import Prelude hiding (log)

-- ANSI color codes
green, cyan, yellow, red, dim, reset :: String
green = "\ESC[32m"
cyan = "\ESC[36m"
yellow = "\ESC[33m"
red = "\ESC[31m"
dim = "\ESC[2m"
reset = "\ESC[0m"

-- Symbols
symStep, symSuccess, symError, symRebuild :: String
symStep = "→ "
symSuccess = "✓ "
symError = "✗ "
symRebuild = "↻ "

-- Core logging: colored symbol + message
log :: MonadIO m => String -> String -> String -> m ()
log color symbol msg = liftIO $ do
  putStrLn $ color ++ symbol ++ reset ++ msg
  hFlush stdout

-- Dim logging: entire message is dimmed, no symbol
logDim :: MonadIO m => String -> m ()
logDim msg = liftIO $ do
  putStrLn $ dim ++ msg ++ reset
  hFlush stdout

-- Convenience aliases
logStep, logSuccess, logError, logRebuild :: MonadIO m => String -> m ()
logStep = log cyan symStep
logSuccess = log green symSuccess
logError = log red symError
logRebuild = log yellow ("\n" ++ symRebuild)

timed :: MonadIO m => String -> m a -> m a
timed label action = do
  logStep label
  start <- liftIO getCurrentTime
  result <- action
  end <- liftIO getCurrentTime
  let ms = realToFrac (diffUTCTime end start) * 1000 :: Double
  logDim $ "  Done in " ++ formatMs ms
  pure result

formatMs :: Double -> String
formatMs ms
  | ms < 1000 = printf "%.0fms" ms
  | otherwise = printf "%.2fs" (ms / 1000)

handleProcessResult :: MonadIO m => String -> (ExitCode, String, String) -> m ()
handleProcessResult processName (exitCode, out, err) =
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure _ -> do
      logError $ processName ++ " failed:"
      unless (null out) $ liftIO $ putStrLn out
      unless (null err) $ liftIO $ putStrLn err
