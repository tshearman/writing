{-# LANGUAGE OverloadedStrings #-}

module Site.Pages.Post
  ( renderPostPage
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, defaultTimeLocale, formatTime)
import Lucid
import SSG.Post (Post (..))
import SSG.Render (renderPandoc)
import Site.Layout (renderPage)

renderPostPage :: Post -> Html ()
renderPostPage post = renderPage (postTitle post) $ article_ $ do
  header_ [class_ "post-header"] $ do
    case postHeroImage post of
      Just url -> img_ [src_ url, class_ "hero-image", alt_ (postTitle post)]
      Nothing  -> pure ()
    h1_ (toHtml (postTitle post))
    div_ [class_ "post-meta"] $ do
      time_ (toHtml (formatDay (postDate post)))
      renderTags (postTags post)
    case postAbstract post of
      Just ab -> p_ [class_ "abstract"] (toHtml ab)
      Nothing -> pure ()
  div_ [class_ "post-body"] (renderPandoc (postBody post))

renderTags :: [Text] -> Html ()
renderTags [] = pure ()
renderTags tags = div_ [class_ "tags"] $
  mapM_ (\t -> a_ [href_ ("/tags/" <> t <> ".html"), class_ "tag"] (toHtml t)) tags

formatDay :: Day -> Text
formatDay = T.pack . formatTime defaultTimeLocale "%B %e, %Y"
