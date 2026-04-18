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

## Math rendering test

The Sine-Gordon equation is a nonlinear hyperbolic partial differential equation in 1+1 dimensions. The equation is:

$$
\frac{\partial^2 \phi}{\partial t^2} - \frac{\partial^2 \phi}{\partial x^2} + \sin(\phi) = 0
$$

Or in subscript notation: $\phi_{tt} - \phi_{xx} + \sin(\phi) = 0$.

This equation arises in differential geometry and physics, describing the motion of a rigid pendulum attached to a stretched wire.

## What's next?

Future posts will explore more features as they're built: margin notes, interactive charts, and compile-time code execution.
