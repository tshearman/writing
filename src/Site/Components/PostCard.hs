{-# LANGUAGE OverloadedStrings #-}

module Site.Components.PostCard
  ( renderPostCard,
    renderTags,
  )
where

import Data.Foldable (traverse_)
import Data.Text (Text)
import Lucid
import SSG.Post (Post (..), postUrl)
import Site.Utils.Format (formatDay)

renderPostCard :: Post -> Html ()
renderPostCard post =
  article_ [class_ "post-card"] $ do
    h2_ $ a_ [href_ (postUrl post)] (toHtml (postTitle post))
    div_ [class_ "post-meta"] $ do
      time_ (toHtml (formatDay (postDate post)))
      renderTags (postTags post)
    traverse_ (p_ [class_ "description"] . toHtml) (postDescription post)

renderTags :: [Text] -> Html ()
renderTags [] = pure ()
renderTags tags =
  div_ [class_ "tags"] $
    mapM_ (span_ [class_ "tag"] . toHtml) tags
