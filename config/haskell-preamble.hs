-- Haskell preamble for code blocks
-- This file contains common imports that are automatically
-- included in all Haskell code blocks during validation
module CodeCheck where

import Data.List (sort, group, nub, sortBy, intercalate)
import Data.Maybe (fromMaybe, isJust, isNothing, catMaybes)
import Data.Char (toUpper, toLower, isDigit, isAlpha)
import Control.Monad (forM_, when, unless)
import Text.Printf (printf)

-- Assertion helper for validating code examples
assert :: Bool -> String -> IO ()
assert True _ = pure ()
assert False msg = error ("Assertion failed: " ++ msg)
