{-# LANGUAGE OverloadedStrings #-}

module Site.Pages.Home
  ( renderHomePage
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, defaultTimeLocale, formatTime)
import Lucid
import SSG.Post (Post (..))
import Site.Layout (renderPage)

renderHomePage :: [Post] -> Html ()
renderHomePage posts = renderPage "Home" $
  div_ [class_ "post-list"] $ do
    h1_ "Recent Posts"
    mapM_ renderPostCard posts

renderPostCard :: Post -> Html ()
renderPostCard post =
  article_ [class_ "post-card"] $ do
    h2_ $ a_ [href_ ("/posts/" <> postSlug post <> ".html")] (toHtml (postTitle post))
    div_ [class_ "post-meta"] $ do
      time_ (toHtml (formatDay (postDate post)))
      renderTags (postTags post)
    case postDescription post of
      Just desc -> p_ [class_ "description"] (toHtml desc)
      Nothing   -> pure ()

renderTags :: [Text] -> Html ()
renderTags [] = pure ()
renderTags tags = div_ [class_ "tags"] $
  mapM_ (\t -> span_ [class_ "tag"] (toHtml t)) tags

formatDay :: Day -> Text
formatDay = T.pack . formatTime defaultTimeLocale "%B %e, %Y"
