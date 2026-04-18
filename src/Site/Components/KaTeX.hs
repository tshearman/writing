{-# LANGUAGE OverloadedStrings #-}

module Site.Components.KaTeX
  ( renderKaTeXScripts,
  )
where

import Data.Text (Text)
import Lucid

renderKaTeXScripts :: Html ()
renderKaTeXScripts = do
  link_
    [ rel_ "stylesheet",
      href_ "https://cdn.jsdelivr.net/npm/katex@0.16.45/dist/katex.min.css",
      integrity_ "sha384-UA8juhPf75SzzAMA/4fo3yOU7sBJ0om7SCD2GHq0fZqZco6tr1UCV7nUbk9J90JM",
      crossorigin_ "anonymous"
    ]
  script_
    [ defer_ "",
      src_ "https://cdn.jsdelivr.net/npm/katex@0.16.45/dist/katex.min.js",
      integrity_ "sha384-Tt7wBxLKwSzFVRET4O4U9H6v8MNaQ/CjN2FMP4xFm0ErrFu6aNqoonRVW5W40iGI",
      crossorigin_ "anonymous"
    ]
    ("" :: Text)
  script_
    [ defer_ "",
      src_ "https://cdn.jsdelivr.net/npm/katex@0.16.45/dist/contrib/auto-render.min.js",
      integrity_ "sha384-bjyGPfbij8/NDKJhSGZNP/khQVgtHUE5exjm4Ydllo42FwIgYsdLO2lXGmRBf5Mz",
      crossorigin_ "anonymous",
      onload_ "renderMathInElement(document.body, {delimiters: [{left: '\\\\[', right: '\\\\]', display: true}, {left: '\\\\(', right: '\\\\)', display: false}]});"
    ]
    ("" :: Text)
