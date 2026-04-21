{-# LANGUAGE OverloadedStrings #-}

module Site.Layout (renderPage) where

import Data.Text (Text)
import Lucid
import Site.Components.KaTeX (renderKaTeXScripts)
import Site.Components.Nav (renderNav)

renderPage :: Text -> Html () -> Html ()
renderPage title content =
  doctypehtml_ $ do
    head_ $ do
      meta_ [charset_ "utf-8"]
      meta_ [name_ "viewport", content_ "width=device-width, initial-scale=1"]
      title_ (toHtml title)
      link_ [rel_ "stylesheet", href_ "/css/style.css"]
      link_ [rel_ "modulepreload", href_ "/pagefind/pagefind.js"]
      renderKaTeXScripts
    body_ $ do
      renderNav
      main_ [class_ "content"] content
