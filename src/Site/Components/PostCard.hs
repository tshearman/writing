{-# LANGUAGE OverloadedStrings #-}

module Site.Components.PostCard
  ( renderPostCard,
    renderTags,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import Lucid
import SSG.Config (htmlExt, postsDir)
import SSG.Post (Post (..))
import Site.Utils.Format (formatDay)

renderPostCard :: Post -> Html ()
renderPostCard post =
  article_ [class_ "post-card"] $ do
    h2_ $ a_ [href_ ("/" <> T.pack postsDir <> "/" <> postSlug post <> T.pack htmlExt)] (toHtml (postTitle post))
    div_ [class_ "post-meta"] $ do
      time_ (toHtml (formatDay (postDate post)))
      renderTags (postTags post)
    case postDescription post of
      Just desc -> p_ [class_ "description"] (toHtml desc)
      Nothing -> pure ()

renderTags :: [Text] -> Html ()
renderTags [] = pure ()
renderTags tags =
  div_ [class_ "tags"] $
    mapM_ (span_ [class_ "tag"] . toHtml) tags
