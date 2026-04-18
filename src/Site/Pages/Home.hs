{-# LANGUAGE OverloadedStrings #-}

module Site.Pages.Home
  ( renderHomePage,
  )
where

import Lucid
import SSG.Post (Post (..))
import Site.Components.PostCard (renderPostCard)
import Site.Layout (renderPage)

renderHomePage :: [Post] -> Html ()
renderHomePage posts =
  renderPage "Home" $
    div_ [class_ "post-list"] $ do
      h1_ "Recent Posts"
      mapM_ renderPostCard posts
