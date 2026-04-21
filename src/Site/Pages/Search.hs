{-# LANGUAGE OverloadedStrings #-}

module Site.Pages.Search (renderSearchPage) where

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

searchScript :: String
searchScript =
  unlines
    [ "import { renderSearchResults, clearSearchResults } from '/js/search.js';",
      "",
      "const pagefind = await import('/pagefind/pagefind.js');",
      "await pagefind.init();",
      "",
      "const input = document.getElementById('search-input');",
      "",
      "input.addEventListener('input', async (e) => {",
      "  const query = e.target.value;",
      "  if (!query) {",
      "    clearSearchResults();",
      "    return;",
      "  }",
      "",
      "  const search = await pagefind.search(query);",
      "  const results = await Promise.all(",
      "    search.results.slice(0, 10).map(r => r.data())",
      "  );",
      "  renderSearchResults(results);",
      "});"
    ]
