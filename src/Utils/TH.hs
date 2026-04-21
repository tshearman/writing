{-# LANGUAGE OverloadedStrings #-}

module Utils.TH (jsonField) where

import Data.Aeson (eitherDecodeFileStrict, (.:))
import Data.Aeson.Key (fromString)
import Data.Aeson.Types (parseEither, withObject)
import qualified Data.Text as T
import Language.Haskell.TH (Exp, Q, litE, runIO, stringL)
import Language.Haskell.TH.Syntax (addDependentFile)

jsonField :: FilePath -> String -> Q Exp
jsonField path field = do
  addDependentFile path
  result <- runIO $ eitherDecodeFileStrict path
  case result >>= parseEither (withObject "config" (.: fromString field)) of
    Left err -> fail $ path ++ ": " ++ err
    Right txt -> litE (stringL (T.unpack txt))
