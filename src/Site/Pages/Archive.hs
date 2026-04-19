{-# LANGUAGE OverloadedStrings #-}

module Site.Pages.Archive
  ( renderArchivePage,
  )
where

import Data.Foldable (traverse_)
import Lucid
import SSG.Post (Post (..), SortedPosts, groupPostsByYear, postUrl)
import Site.Layout (renderPage)
import Site.Utils.Format (formatDay, getYear)

renderArchivePage :: SortedPosts -> Html ()
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
    a_ [href_ (postUrl post)] (toHtml (postTitle post))
    traverse_ (\desc -> span_ [class_ "description"] (toHtml $ " — " <> desc)) (postDescription post)
