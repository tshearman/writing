{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module SSG.App
  ( App,
    Env (..),
    BuildMode (..),
    runApp,
  )
where

import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Logger (LoggingT, MonadLogger, runStdoutLoggingT)
import Control.Monad.Reader (MonadReader, ReaderT, runReaderT)

data BuildMode = ProductionMode | DevelopmentMode
  deriving (Eq)

data Env = Env
  { envBuildMode :: BuildMode,
    envWithSearch :: Bool
  }

newtype App a = App {unApp :: LoggingT (ReaderT Env IO) a}
  deriving
    ( Functor,
      Applicative,
      Monad,
      MonadIO,
      MonadLogger,
      MonadReader Env
    )

runApp :: BuildMode -> Bool -> App a -> IO a
runApp mode withSearch = flip runReaderT env . runStdoutLoggingT . unApp
  where
    env = Env {envBuildMode = mode, envWithSearch = withSearch}
