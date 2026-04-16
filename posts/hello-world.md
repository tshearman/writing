---
title: "Hello World"
description: "A first post to test the custom static site generator."
abstract: "This post exercises the basic features of the SSG: markdown rendering, code blocks, and inline formatting."
pubDate: "2026-04-15"
tags: [intro, test]
draft: false
featured: true
---

Welcome to my blog, powered by a custom Haskell static site generator.

## Why build a custom SSG?

Building a static site generator from scratch is a great way to learn Haskell. We get to work with:

- **Pandoc** for markdown parsing
- **lucid2** for type-safe HTML composition
- **aeson** and **yaml** for data parsing

## A code example

Here's a simple Haskell function:

```haskell
fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n - 1) + fib (n - 2)
```

And some Python:

```python
def fib(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a
```

## What's next?

Future posts will explore more features as they're built: math rendering with KaTeX, margin notes, interactive charts, and compile-time code execution.
