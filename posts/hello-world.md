---
title: "Hello World"
description: "A first post to test the custom static site generator."
pubDate: "2026-04-15"
tags: [intro, test]
draft: false
featured: true
---

Welcome to my blog, powered by a custom Haskell static site generator.

## Why build a custom SSG?

Building a static site generator from scratch is a great way to learn Haskell.^[This is a sidenote rendered in the margin. Sidenotes keep the reader's flow intact while providing additional context.] We get to work with:

- **Pandoc** for markdown parsing
- **lucid2** for type-safe HTML composition
- **aeson** and **yaml** for data parsing

> "Programs must be written for people to read, and only incidentally for machines to execute."
>
> — Harold Abelson, _Structure and Interpretation of Computer Programs_

## Text formatting

The renderer supports various inline formatting:

- _Emphasis_ and **strong** text
- ~~Strikethrough~~ for deleted content
- H~2~O uses subscript, and x^2^ uses superscript
- Inline `code` for technical terms

You can also include [links](https://haskell.org "The Haskell Programming Language") with optional titles.

---

## A code example

Here's a simple Haskell function:

```haskell
fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n - 1) + fib (n - 2)

main = do
  assert (fib 4 == 3) "fib 4 should be 3"
  assert (fib 10 == 55) "fib 10 should be 55"
```

And some Python for comparison:

```python
def fib(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a
```

## Math rendering

The Sine-Gordon equation^[Named after the Klein-Gordon equation, as a pun on "sinus" (sine).] is a nonlinear hyperbolic partial differential equation in 1+1 dimensions:

$$
\frac{\partial^2 \phi}{\partial t^2} - \frac{\partial^2 \phi}{\partial x^2} + \sin(\phi) = 0
$$

Or in subscript notation: $\phi_{tt} - \phi_{xx} + \sin(\phi) = 0$.

The Euler identity $e^{i\pi} + 1 = 0$ connects five fundamental constants.

## Tables

| Feature          | Status   | Notes           |
| ---------------- | -------- | --------------- |
| Markdown parsing | Complete | Via Pandoc      |
| Math rendering   | Complete | KaTeX           |
| Code validation  | Complete | GHC             |
| Sidenotes        | Complete | Footnote syntax |

## Ordered lists

Steps to build the SSG:

1. Parse markdown with Pandoc
2. Extract frontmatter metadata
3. Render to HTML with lucid2
4. Validate code blocks
5. Write output files

## Poetry and line blocks

| Roses are red,
| Violets are blue,
| Haskell is pure,
| And lazy too.

## Images

The SSG supports images from three sources:

**Static images** (from `static/images/`):

![Test pattern](/images/nix.svg "A simple test pattern"){width=100px height=100px}

**External images** (absolute URLs):

![Haskell logo](https://www.haskell.org/img/haskell-logo.svg "The Haskell logo")

**Post-local images** can be placed alongside markdown files and referenced with relative paths like `./diagram.png`.
