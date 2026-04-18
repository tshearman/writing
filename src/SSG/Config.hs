module SSG.Config
  ( postsDir,
    staticDir,
    outputDir,
    markdownExt,
    htmlExt,
    homepageFile,
    frontmatterDelimiter,
    devServerPort,
    rebuildDebounceMs,
    siteTitle,
  )
where

-- | Output directory for built site
outputDir :: FilePath
outputDir = "_site"

-- | Source directory for markdown posts
postsDir :: FilePath
postsDir = "posts"

-- | Source directory for static assets
staticDir :: FilePath
staticDir = "static"

-- | Markdown file extension
markdownExt :: String
markdownExt = ".md"

-- | HTML file extension
htmlExt :: String
htmlExt = ".html"

-- | Homepage filename
homepageFile :: FilePath
homepageFile = "index.html"

-- | Frontmatter delimiter for markdown posts
frontmatterDelimiter :: String
frontmatterDelimiter = "---"

-- | Development server port
devServerPort :: Int
devServerPort = 8000

-- | File watcher debounce delay in milliseconds
rebuildDebounceMs :: Int
rebuildDebounceMs = 1000

-- | Site title
siteTitle :: String
siteTitle = "writing"
