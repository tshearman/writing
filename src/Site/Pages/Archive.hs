{-# LANGUAGE OverloadedStrings #-}

module Site.Pages.Archive
  ( renderArchivePage,
  )
where

import qualified Data.Text as T
import Lucid
import SSG.Config (htmlExt, postsDir)
import SSG.Post (Post (..), groupPostsByYear)
import Site.Layout (renderPage)
import Site.Utils.Format (formatDay, getYear)

renderArchivePage :: [Post] -> Html ()
renderArchivePage posts =
  renderPage "Archive" $
    div_ [class_ "archive"] $ do
      h1_ "Archive"
      mapM_ renderYearGroup (groupPostsByYear getYear posts)

renderYearGroup :: (Integer, [Post]) -> Html ()
renderYearGroup (year, posts) =
  div_ [class_ "year-group"] $ do
    h2_ (toHtml $ show year)
    ul_ [class_ "archive-list"] $
      mapM_ renderArchiveItem posts

renderArchiveItem :: Post -> Html ()
renderArchiveItem post =
  li_ $ do
    span_ [class_ "date"] (toHtml $ formatDay (postDate post))
    a_ [href_ ("/" <> T.pack postsDir <> "/" <> postSlug post <> T.pack htmlExt)] $
      toHtml (postTitle post)
    case postDescription post of
      Just desc -> span_ [class_ "description"] (toHtml $ " — " <> desc)
      Nothing -> pure ()
