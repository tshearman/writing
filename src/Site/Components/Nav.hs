{-# LANGUAGE OverloadedStrings #-}

module Site.Components.Nav
  ( renderNav,
  )
where

import Data.Text (pack)
import Lucid
import SSG.Config (siteTitle)

renderNav :: Html ()
renderNav =
  nav_ [class_ "site-nav"] $
    div_ [class_ "nav-inner"] $ do
      a_ [href_ "/", class_ "site-title"] (toHtml $ pack siteTitle)
      div_ [class_ "nav-links"] $ do
        a_ [href_ "/"] "Home"
        a_ [href_ "/archive.html"] "Archive"
