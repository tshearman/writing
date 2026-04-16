{-# LANGUAGE OverloadedStrings #-}

module Site.Layout
  ( renderPage
  ) where

import Data.Text (Text)
import Lucid

renderPage :: Text -> Html () -> Html ()
renderPage title content =
  doctypehtml_ $ do
    head_ $ do
      meta_ [charset_ "utf-8"]
      meta_ [name_ "viewport", content_ "width=device-width, initial-scale=1"]
      title_ (toHtml title)
      link_ [rel_ "stylesheet", href_ "/css/style.css"]
      link_ [rel_ "stylesheet",
             href_ "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"]
      script_ [defer_ "", src_ "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"] ("" :: Text)
      script_ [defer_ "",
               src_ "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"] ("" :: Text)
      script_ [defer_ "", src_ "/js/katex-init.js"] ("" :: Text)
    body_ $ do
      nav_ [class_ "site-nav"] $
        div_ [class_ "nav-inner"] $ do
          a_ [href_ "/", class_ "site-title"] "writing"
          div_ [class_ "nav-links"] $ do
            a_ [href_ "/"] "Home"
            a_ [href_ "/archive.html"] "Archive"
      main_ [class_ "content"] content
      footer_ [class_ "site-footer"] $
        p_ "Powered by a custom Haskell SSG"
