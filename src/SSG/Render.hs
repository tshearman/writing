{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}

module SSG.Render
  ( renderPandoc
  , renderBlocks
  , renderInlines
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Lucid
import Text.Blaze.Html.Renderer.Text (renderHtml)
import Text.Pandoc.Definition
import qualified Skylighting as Sky

renderPandoc :: Pandoc -> Html ()
renderPandoc (Pandoc _ blocks) = renderBlocks blocks

renderBlocks :: [Block] -> Html ()
renderBlocks = mapM_ renderBlock

renderBlock :: Block -> Html ()
renderBlock (Para inlines)         = p_ (renderInlines inlines)
renderBlock (Plain inlines)        = renderInlines inlines
renderBlock (Header level _ inls)  = withLevel level (renderInlines inls)
renderBlock (BlockQuote blocks)    = blockquote_ (renderBlocks blocks)
renderBlock (BulletList items)     = ul_ $ mapM_ (li_ . renderBlocks) items
renderBlock (OrderedList _ items)  = ol_ $ mapM_ (li_ . renderBlocks) items
renderBlock (CodeBlock attr code)  = renderCodeBlock attr code
renderBlock (RawBlock "html" raw)  = toHtmlRaw raw
renderBlock HorizontalRule         = hr_ []
renderBlock (Div attr blocks)      = divWithAttr attr (renderBlocks blocks)
renderBlock (Table _ _ _ thead tbodies tfoot) = renderTable thead tbodies tfoot
renderBlock (LineBlock lns)        = div_ [class_ "line-block"] $
                                       mapM_ (\l -> do renderInlines l; br_ []) lns
renderBlock _                      = pure ()

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
renderInline (Str t)              = toHtml t
renderInline Space                = " "
renderInline SoftBreak            = " "
renderInline LineBreak            = br_ []
renderInline (Emph inls)          = em_ (renderInlines inls)
renderInline (Underline inls)     = span_ [style_ "text-decoration: underline"] (renderInlines inls)
renderInline (Strong inls)        = strong_ (renderInlines inls)
renderInline (Strikeout inls)     = del_ (renderInlines inls)
renderInline (Superscript inls)   = sup_ (renderInlines inls)
renderInline (Subscript inls)     = sub_ (renderInlines inls)
renderInline (Code _ t)           = code_ (toHtml t)
renderInline (Link _ inls (url, title)) =
  a_ (href_ url : [title_ title | not (T.null title)]) (renderInlines inls)
renderInline (Image _ inls (url, title)) =
  img_ (src_ url : alt_ (inlinesToText inls) : [title_ title | not (T.null title)])
renderInline (RawInline "html" raw) = toHtmlRaw raw
renderInline (Math InlineMath t)  = span_ [class_ "math inline"] $ toHtmlRaw $ "\\(" <> t <> "\\)"
renderInline (Math DisplayMath t) = div_ [class_ "math display"] $ toHtmlRaw $ "\\[" <> t <> "\\]"
renderInline (Note blocks)        = renderFootnote blocks
renderInline (Span attr inls)     = spanWithAttr attr (renderInlines inls)
renderInline _                    = pure ()

renderFootnote :: [Block] -> Html ()
renderFootnote blocks =
  span_ [class_ "sidenote"] (renderBlocks blocks)

renderCodeBlock :: Attr -> Text -> Html ()
renderCodeBlock (_, classes, _) code =
  case lang >>= flip Sky.lookupSyntax Sky.defaultSyntaxMap of
    Just syntax ->
      case Sky.tokenize (Sky.TokenizerConfig Sky.defaultSyntaxMap False) syntax code of
        Right tokens -> pre_ $ code_ [class_ ("language-" <> langName)] $
          toHtmlRaw (TL.toStrict $ renderHtml $ Sky.formatHtmlBlock Sky.defaultFormatOpts tokens)
        Left _ -> plainCodeBlock
    Nothing -> plainCodeBlock
  where
    lang = if null classes then Nothing else Just (head classes)
    langName = maybe "" id lang
    plainCodeBlock = pre_ $ code_ (toHtml code)

divWithAttr :: Attr -> Html () -> Html ()
divWithAttr ("", [], []) inner = div_ inner
divWithAttr (ident, classes, _) inner =
  div_ (attrList ident classes) inner

spanWithAttr :: Attr -> Html () -> Html ()
spanWithAttr ("", [], []) inner = span_ inner
spanWithAttr (ident, classes, _) inner =
  span_ (attrList ident classes) inner

attrList :: Text -> [Text] -> [Attributes]
attrList ident classes =
  [id_ ident | not (T.null ident)] ++
  [class_ (T.intercalate " " classes) | not (null classes)]

inlinesToText :: [Inline] -> Text
inlinesToText = T.concat . map go
  where
    go (Str t)       = t
    go Space         = " "
    go SoftBreak     = " "
    go (Emph inls)   = inlinesToText inls
    go (Strong inls) = inlinesToText inls
    go _             = ""

renderTable :: TableHead -> [TableBody] -> TableFoot -> Html ()
renderTable (TableHead _ headRows) bodies (TableFoot _ footRows) =
  table_ $ do
    unless (null headRows) $ thead_ $ mapM_ renderRow headRows
    mapM_ (\(TableBody _ _ _ rows) -> tbody_ $ mapM_ renderRow rows) bodies
    unless (null footRows) $ tfoot_ $ mapM_ renderRow footRows
  where
    renderRow :: Row -> Html ()
    renderRow (Row _ cells) = tr_ $ mapM_ renderCell cells
    renderCell :: Cell -> Html ()
    renderCell (Cell _ _ _ _ blocks) = td_ (renderBlocks blocks)
    unless :: Bool -> Html () -> Html ()
    unless False m = m
    unless True  _ = pure ()
