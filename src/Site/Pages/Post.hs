{-# LANGUAGE OverloadedStrings #-}

module Site.Pages.Post
  ( renderPostPage,
  )
where

import Data.Text (Text)
import Lucid
import SSG.Post (Post (..))
import SSG.Render (renderPandoc)
import Site.Layout (renderPage)
import Site.Utils.Format (formatDay)

renderPostPage :: Post -> Html ()
renderPostPage post =
  renderPage (postTitle post) $
    article_ $ do
      header_ [class_ "post-header"] $ do
        h1_ (toHtml (postTitle post))
        div_ [class_ "post-meta"] $ do
          time_ (toHtml (formatDay (postDate post)))
          renderTagsWithLinks (postTags post)
      div_ [class_ "post-body"] (renderPandoc (postBody post))

-- Post page uses linked tags (pointing to tag archive pages)
renderTagsWithLinks :: [Text] -> Html ()
renderTagsWithLinks [] = pure ()
renderTagsWithLinks tags =
  div_ [class_ "tags"] $
    mapM_ (\t -> a_ [href_ ("/tags/" <> t <> ".html"), class_ "tag"] (toHtml t)) tags
