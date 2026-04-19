{-# LANGUAGE OverloadedStrings #-}

module Site.Pages.Search
  ( renderSearchPage,
  )
where

import Lucid
import Site.Layout (renderPage)

renderSearchPage :: Html ()
renderSearchPage =
  renderPage "Search" $ do
    h1_ "Search"
    div_ [class_ "search-container"] $ do
      input_ [type_ "text", id_ "search-input", placeholder_ "Search posts..."]
      ul_ [id_ "search-results"] ""
    script_ [type_ "module"] searchScript

-- | Haskell-generated JS function that formats a search result as HTML.
-- Takes Pagefind result data and returns an HTML string.
renderResultJS :: String
renderResultJS =
  unlines
    [ "function renderResult(data) {"
    , "  const title = data.meta.title || data.url;"
    , "  const excerpt = data.excerpt || '';"
    , "  const url = data.url;"
    , "  return `"
    , "    <li class=\"search-result\">"
    , "      <a class=\"search-result-link\" href=\"${url}\">"
    , "        <span class=\"search-result-title\">${title}</span>"
    , "      </a>"
    , "      <p class=\"search-result-excerpt\">${excerpt}</p>"
    , "    </li>"
    , "  `;"
    , "}"
    ]

searchScript :: String
searchScript =
  unlines
    [ "const pagefind = await import('/pagefind/pagefind.js');"
    , "await pagefind.init();"
    , ""
    , renderResultJS
    , ""
    , "const input = document.getElementById('search-input');"
    , "const results = document.getElementById('search-results');"
    , ""
    , "input.addEventListener('input', async (e) => {"
    , "  const query = e.target.value;"
    , "  results.innerHTML = '';"
    , "  if (!query) return;"
    , ""
    , "  const search = await pagefind.search(query);"
    , "  const html = await Promise.all("
    , "    search.results.slice(0, 10).map(async (r) => renderResult(await r.data()))"
    , "  );"
    , "  results.innerHTML = html.join('');"
    , "});"
    ]
