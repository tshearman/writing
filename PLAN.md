# Custom Haskell Static Site Generator — Implementation Plan

## Context

Build a custom static site generator from scratch using Pandoc + lucid2. The goal is a Substack-like personal blog with type-safe composable HTML (no templates), markdown posts with rich features (math, charts, margin notes, runnable code snippets), and static search. A small backend for newsletter signups will run alongside via docker-compose but is deferred to a later phase.

**Starting from a clean slate** — all previous code (Obelisk, Hakyll) has been removed. Every file listed below will be created new.

**This is a learning project.** The build-out doubles as a tutorial introduction to Haskell features: type classes, monads (via lucid's `HtmlT`), GADTs (if useful for routing), `aeson` generics, Pandoc AST walking, etc. Code should be minimal and readable — favor clarity over abstraction, keep line count low, and let each phase introduce one or two new Haskell concepts naturally.

The key architectural choice: **lucid2 for HTML composition** instead of template files. Every page is a Haskell function returning `Html ()`, making layouts composable and type-checked.

---

## File Structure

```
writing/
├── flake.nix
├── ssg.cabal
├── app/
│   └── Main.hs                    -- CLI entry: build / watch / clean
├── src/
│   ├── SSG/
│   │   ├── Build.hs               -- orchestrates the full build pipeline
│   │   ├── Post.hs                -- Post type, frontmatter parsing (yaml + aeson)
│   │   ├── Markdown.hs            -- Pandoc reader config, custom filters
│   │   ├── Render.hs              -- Pandoc → lucid HTML bridge
│   │   ├── Tags.hs                -- tag index generation
│   │   ├── Feed.hs                -- RSS/Atom feed
│   │   ├── Search.hs              -- Pagefind integration (post-build step)
│   │   ├── Charts.hs              -- ECharts data helpers, JSON generation
│   │   ├── CodeRunner.hs          -- compile-time code block execution
│   │   └── Watch.hs               -- fsnotify-based file watcher + rebuild
│   └── Site/
│       ├── Layout.hs              -- base document, <head>, nav, footer
│       ├── Components.hs          -- reusable: card, tag pill, margin note, etc.
│       └── Pages/
│           ├── Home.hs            -- landing page with recent/featured posts
│           ├── Post.hs            -- single post page
│           ├── Archive.hs         -- all posts chronologically
│           ├── Tag.hs             -- posts filtered by tag
│           └── Search.hs          -- search UI shell (Pagefind JS does the work)
├── posts/
│   └── hello-world.md             -- first sample post
├── static/
│   ├── css/style.css
│   ├── js/katex-init.js
│   └── images/
├── _site/                         -- build output (gitignored)
└── docker/
    └── compose.yaml               -- newsletter service (Phase 6)
```

---

## Phase 1 — Foundation (get a blog rendering)

**Goal:** Markdown posts build to styled HTML pages via lucid. Dev environment works.

### 1a. Nix flake + cabal project

Create `flake.nix`:
- GHC 9.6 via `haskellPackages` (nixos-24.05)
- Only the deps needed for Phase 1: `pandoc`, `lucid2`, `aeson`, `yaml`, `text`, `filepath`, `directory`, `optparse-applicative`, `warp`, `wai`, `wai-app-static`
- Dev tools: `cabal-install`, `haskell-language-server`, `ghcid`, `ormolu`
- Shell hook announcing available commands
- `.envrc` with `use flake`

Create `ssg.cabal`:
- Library in `src/`, executable in `app/`
- Add deps incrementally per phase (don't front-load everything)

Create `.gitignore`: `_site/`, `_cache/`, `dist-newstyle/`, `.direnv/`, `result`

### 1b. Post type + frontmatter parsing

`SSG/Post.hs`:
```haskell
data Post = Post
  { postTitle       :: Text
  , postDescription :: Maybe Text
  , postAbstract    :: Maybe Text
  , postDate        :: Day
  , postTags        :: [Text]
  , postDraft       :: Bool
  , postFeatured    :: Bool
  , postHeroImage   :: Maybe Text
  , postSlug        :: Text        -- derived from filename
  , postBody        :: Pandoc      -- parsed AST
  }
```
- Parse YAML frontmatter by splitting on `---` delimiters, decode via `aeson`/`yaml`
- Parse body via Pandoc `readMarkdown`

### 1c. Pandoc → lucid bridge

`SSG/Render.hs`:
- Walk `Pandoc` AST blocks/inlines and emit `lucid2` `Html ()` values
- This is the core bridge — a recursive function over Pandoc's `Block` and `Inline` types
- Use `skylighting` for code block syntax highlighting (render to HTML classes)

### 1d. Page layouts in lucid

`Site/Layout.hs` — base document shell:
- `<head>` with meta, CSS, KaTeX CDN links
- Nav bar, main content slot, footer
- `renderPage :: Text -> Html () -> Html ()` wraps content in the shell

`Site/Pages/Post.hs` — single post:
- Hero image, title, date, tags, rendered body

`Site/Pages/Home.hs` — recent posts list with cards

### 1e. Build pipeline

`SSG/Build.hs`:
- Glob `posts/*.md`, parse each, filter drafts
- Sort by date descending
- Render each post page, home page
- Copy `static/` to `_site/`
- Write all HTML to `_site/`

`app/Main.hs`:
- `build` — run full build
- `clean` — remove `_site/`
- `watch` — build + serve via warp on localhost:8000 + fsnotify rebuild

### 1f. Basic CSS

Create `static/css/style.css` — clean typography, responsive layout, CSS variables for theming. Minimal: ~100 lines to start.

**Verification:** `cabal run ssg -- build` produces `_site/` with working HTML. `cabal run ssg -- watch` serves on localhost:8000.

---

## Phase 2 — Content Features

**Goal:** Rich post content — math, footnotes, margin notes, syntax highlighting.

### 2a. KaTeX math rendering

- Pandoc already parses `$...$` and `$$...$$` as `Math` inlines/blocks
- In `Render.hs`, emit `<span class="math inline">` / `<div class="math display">` 
- KaTeX auto-render script in layout + create `js/katex-init.js`

### 2b. Footnotes → margin notes

- Pandoc parses `[^1]` footnotes into `Note` inlines
- Custom rendering in `Render.hs`: emit `<span class="sidenote">` (Tufte CSS pattern)
- CSS: float sidenotes to margin on wide screens, collapse to inline on narrow
- Provide a `{.margin-note}` class on spans for explicit margin notes (Pandoc `Span` with attributes)

### 2c. Syntax highlighting

- `skylighting` integration in `Render.hs` for `CodeBlock` nodes
- Emit highlighted HTML with appropriate CSS classes
- Include a skylighting theme CSS file in the layout

**Verification:** Post with `$$\sum_{i=0}^n$$`, footnotes, and code blocks renders correctly with math, sidenotes, and highlighted code.

---

## Phase 3 — Site Features

**Goal:** Navigation, discovery, search.

### 3a. Tagging system

`SSG/Tags.hs`:
- Collect all tags across posts, generate tag → [Post] index
- `Site/Pages/Tag.hs` — filtered post list per tag
- Tag pills on post pages link to tag pages

### 3b. Archive page

`Site/Pages/Archive.hs` — all posts grouped by year

### 3c. RSS/Atom feed

`SSG/Feed.hs`:
- Generate `_site/feed.xml` with post summaries
- Use `xml-conduit` or hand-build with lucid-like approach

### 3d. Pagefind search

`SSG/Search.hs`:
- After HTML build, shell out to `pagefind --site _site`
- Pagefind indexes all HTML content, generates JS bundle
- `Site/Pages/Search.hs` — page with Pagefind UI `<div id="search">` + script tag
- Add `pagefind` to flake `buildInputs` (or fetch via nix)

**Verification:** Tag pages work. Search finds posts by title, content, and tags. RSS feed validates.

---

## Phase 4 — Interactive Charts

**Goal:** Embed Apache ECharts in posts.

### Approach

Posts use fenced code blocks with `echart` language:

````markdown
```echart
{ "xAxis": { "data": ["Mon","Tue","Wed"] },
  "series": [{ "type": "bar", "data": [120, 200, 150] }] }
```
````

### Implementation

`SSG/Charts.hs`:
- During Pandoc AST walk, detect `CodeBlock` with `echart` class
- Validate JSON via `aeson`
- Emit `<div class="echart" data-options='...'>` with JSON as data attribute

Layout includes ECharts CDN + small init script that finds `.echart` divs and calls `echarts.init()`.

For Haskell-generated chart data: author can write a companion `.hs` file that produces JSON, executed at build time (reuses Phase 5 infrastructure).

**Verification:** Post with an echart block renders an interactive bar chart in the browser.

---

## Phase 5 — Compile-Time Code Execution

**Goal:** Code blocks in posts are executed at build time; output is captured and displayed. Build fails if any snippet errors.

### Approach

Fenced code blocks with `run` attribute are executed:

````markdown
```python run
print("hello")
```
````

Renders as the code block + an output block showing `hello`.

### Implementation

`SSG/CodeRunner.hs`:

1. **AST pass:** Find `CodeBlock` nodes with `run` attribute, extract language + source
2. **Execute:** Per language:
   - **Python** → `python3 -c <source>` (available in flake `buildInputs`)
   - **Haskell** → `runghc <tmpfile.hs>` (GHC already in env)
   - **Common Lisp** → `sbcl --script <tmpfile.lisp>` (add `sbcl` to flake)
   - **Shell** → `bash -c <source>`
   - Additional languages added by putting the interpreter in the flake
3. **Capture:** stdout + stderr, exit code
4. **Inject:** Replace the single `CodeBlock` with two blocks: source (highlighted) + output
5. **Fail build** if exit code != 0 (ensures accuracy)

### Safety

- Execution happens at build time on the author's machine — no sandboxing needed (it's your own code)
- Timeout per snippet (e.g., 30 seconds) via `System.Timeout`
- Snippets run sequentially by default; could parallelize later

### Flake additions

Add to `buildInputs`: `python3`, `sbcl`, `ghc` (already present)

**Verification:** Post with Python and Haskell `run` blocks builds successfully, output appears below each snippet. Intentionally broken snippet causes build failure.

---

## Phase 6 — Backend Services (Deferred)

**Goal:** Newsletter signup endpoint.

### Approach

- Small Haskell service using `warp` + `servant`
- SQLite for subscriber storage
- Single endpoint: `POST /api/subscribe` with email validation
- Runs in `docker/compose.yaml` alongside a static file server (nginx or caddy) for `_site/`

### Implementation (when ready)

```
docker/
├── compose.yaml
├── newsletter/
│   ├── Dockerfile
│   ├── newsletter.cabal
│   └── src/Main.hs
```

- Frontend: signup form component in lucid, JS fetch to `/api/subscribe`
- Could add email verification, unsubscribe later

**Not blocking any other phase.** The static site works standalone; docker-compose adds optional services.

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `lucid2` | Composable HTML monads |
| `pandoc` | Markdown parsing |
| `skylighting` | Syntax highlighting |
| `aeson` | JSON (chart data, frontmatter) |
| `yaml` | YAML frontmatter |
| `warp` | Dev server (watch mode) |
| `wai` | WAI middleware (static files) |
| `wai-app-static` | Serve `_site/` directory |
| `fsnotify` | File watching for rebuild |
| `optparse-applicative` | CLI argument parsing |
| `xml-conduit` | RSS feed generation |
| `typed-process` | Code block execution |
| `text`, `filepath`, `directory`, `time` | Standard utilities |

## Verification Plan

After each phase, verify by:
1. `nix develop` enters shell without errors
2. `cabal build` compiles without warnings (use `-Wall -Werror`)
3. `cabal run ssg -- build` produces `_site/` with expected files
4. `cabal run ssg -- watch` serves on localhost:8000, pages render correctly in browser
5. Modify a post → rebuild triggers automatically, changes visible on refresh
6. For Phase 5: add a broken code snippet → build must fail with clear error message
