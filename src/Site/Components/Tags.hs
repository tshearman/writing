{-# LANGUAGE OverloadedStrings #-}

module Site.Components.Tags
  ( renderTags,
  )
where

import Data.Text (Text)
import Lucid

renderTags :: [Text] -> Html ()
renderTags [] = pure ()
renderTags tags =
  div_ [class_ "tags"] $
    mapM_ (span_ [class_ "tag"] . toHtml) tags
