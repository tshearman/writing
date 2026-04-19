{-# LANGUAGE OverloadedStrings #-}

module SSG.Render
  ( renderPandoc,
    renderBlocks,
    renderInlines,
  )
where

import Control.Monad (unless)
import Data.Text (Text)
import qualified Data.Text as T
import Lucid
import Lucid.Base (makeAttributes)
import Text.Pandoc.Definition

renderPandoc :: Pandoc -> Html ()
renderPandoc (Pandoc _ blocks) = renderBlocks blocks

renderBlocks :: [Block] -> Html ()
renderBlocks = mapM_ renderBlock

renderBlock :: Block -> Html ()
renderBlock (Para inlines) = p_ (renderInlines inlines)
renderBlock (Plain inlines) = renderInlines inlines
renderBlock (Header level _ inls) = withLevel level (renderInlines inls)
renderBlock (BlockQuote blocks) = blockquote_ (renderBlocks blocks)
renderBlock (BulletList items) = ul_ $ mapM_ (li_ . renderBlocks) items
renderBlock (OrderedList _ items) = ol_ $ mapM_ (li_ . renderBlocks) items
renderBlock (CodeBlock attr code) = renderCodeBlock attr code
renderBlock (RawBlock "html" raw) = toHtmlRaw raw
renderBlock HorizontalRule = hr_ []
renderBlock (Div attr blocks) = divWithAttr attr (renderBlocks blocks)
renderBlock (Table _ _ _ thead tbodies tfoot) = renderTable thead tbodies tfoot
renderBlock (LineBlock lns) = div_ [class_ "line-block"] $ mapM_ (\l -> renderInlines l >> br_ []) lns
renderBlock DefinitionList {} = pure () -- not supported
renderBlock Figure {} = pure () -- not supported
renderBlock RawBlock {} = pure () -- non-HTML raw blocks ignored

withLevel :: Int -> Html () -> Html ()
withLevel 1 = h1_
withLevel 2 = h2_
withLevel 3 = h3_
withLevel 4 = h4_
withLevel 5 = h5_
withLevel _ = h6_

renderInlines :: [Inline] -> Html ()
renderInlines = mapM_ renderInline

renderInline :: Inline -> Html ()
renderInline (Str t) = toHtml t
renderInline Space = " "
renderInline SoftBreak = " "
renderInline LineBreak = br_ []
renderInline (Emph inls) = em_ (renderInlines inls)
renderInline (Underline inls) = span_ [style_ "text-decoration: underline"] (renderInlines inls)
renderInline (Strong inls) = strong_ (renderInlines inls)
renderInline (Strikeout inls) = del_ (renderInlines inls)
renderInline (Superscript inls) = sup_ (renderInlines inls)
renderInline (Subscript inls) = sub_ (renderInlines inls)
renderInline (Code _ t) = code_ (toHtml t)
renderInline (Link _ inls (url, title)) =
  a_ (href_ url : [title_ title | not (T.null title)]) (renderInlines inls)
renderInline (Image attr inls target) = renderImage attr inls target
renderInline (RawInline "html" raw) = toHtmlRaw raw
renderInline (Math InlineMath t) = span_ [class_ "math inline"] $ toHtmlRaw $ "\\(" <> t <> "\\)"
renderInline (Math DisplayMath t) = div_ [class_ "math display"] $ toHtmlRaw $ "\\[" <> t <> "\\]"
renderInline (Note blocks) = renderFootnote blocks
renderInline (Span attr inls) = spanWithAttr attr (renderInlines inls)
renderInline (Quoted SingleQuote inls) =
  toHtmlRaw ("&lsquo;" :: Text) >> renderInlines inls >> toHtmlRaw ("&rsquo;" :: Text)
renderInline (Quoted DoubleQuote inls) =
  toHtmlRaw ("&ldquo;" :: Text) >> renderInlines inls >> toHtmlRaw ("&rdquo;" :: Text)
renderInline Cite {} = pure () -- not supported
renderInline SmallCaps {} = pure () -- not supported
renderInline RawInline {} = pure () -- non-HTML raw inlines ignored

renderFootnote :: [Block] -> Html ()
renderFootnote blocks =
  span_ [class_ "sidenote"] (renderBlocks blocks)

renderImage :: Attr -> [Inline] -> Target -> Html ()
renderImage (_, _, kvs) inls (url, title) =
  img_ $
    [src_ url, alt_ (inlinesToText inls)]
      ++ [title_ title | not (T.null title)]
      ++ [width_ w | Just w <- [lookup "width" kvs]]
      ++ [height_ h | Just h <- [lookup "height" kvs]]

renderCodeBlock :: Attr -> Text -> Html ()
renderCodeBlock (_, classes, _) code =
  pre_ $ case classes of
    [] -> code_ (toHtml code)
    (c : _) -> code_ [class_ ("language-" <> c)] (toHtml code)

divWithAttr :: Attr -> Html () -> Html ()
divWithAttr ("", [], []) inner = div_ inner
divWithAttr attr inner = div_ (attrList attr) inner

spanWithAttr :: Attr -> Html () -> Html ()
spanWithAttr ("", [], []) inner = span_ inner
spanWithAttr attr inner = span_ (attrList attr) inner

attrList :: Attr -> [Attributes]
attrList (ident, classes, kvs) =
  [id_ ident | not (T.null ident)]
    ++ [class_ (T.intercalate " " classes) | not (null classes)]
    ++ map (uncurry makeAttributes) kvs

inlinesToText :: [Inline] -> Text
inlinesToText = T.concat . map f
  where
    f (Str t) = t
    f Space = " "
    f SoftBreak = " "
    f LineBreak = " "
    f (Emph inls) = inlinesToText inls
    f (Strong inls) = inlinesToText inls
    f (Strikeout inls) = inlinesToText inls
    f (Superscript inls) = inlinesToText inls
    f (Subscript inls) = inlinesToText inls
    f (Underline inls) = inlinesToText inls
    f (Span _ inls) = inlinesToText inls
    f (Quoted _ inls) = inlinesToText inls
    f (Code _ t) = t
    f (Math _ t) = t
    f _ = "" -- Note, Cite, Link, Image, RawInline

renderTable :: TableHead -> [TableBody] -> TableFoot -> Html ()
renderTable (TableHead _ headRows) bodies (TableFoot _ footRows) =
  table_ $ do
    unless (null headRows) $ thead_ $ mapM_ (renderRow th_) headRows
    mapM_ (\(TableBody _ _ _ rows) -> tbody_ $ mapM_ (renderRow td_) rows) bodies
    unless (null footRows) $ tfoot_ $ mapM_ (renderRow td_) footRows
  where
    renderRow :: (Html () -> Html ()) -> Row -> Html ()
    renderRow cell (Row _ cells) = tr_ $ mapM_ (renderCell cell) cells
    renderCell :: (Html () -> Html ()) -> Cell -> Html ()
    renderCell cell (Cell _ _ _ _ blocks) = cell (renderBlocks blocks)
