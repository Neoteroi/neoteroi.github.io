---
title: GuardPost - Authentication and Authorization for Python
no_comments: true
---

# GuardPost is an authentication and authorization framework for Python

```shell
pip install guardpost
```

## GuardPost offers...

- A **strategy pattern** for authentication — determine who or what is initiating an action.
- A **policy-based** authorization model — determine whether the acting identity is allowed to do something.
- Built-in support for **JSON Web Tokens (JWTs)** validation, including RSA (RS256, RS384, RS512) and EC (ES256, ES384, ES512) asymmetric algorithms, and symmetric HMAC algorithms (HS256, HS384, HS512).
- Automatic handling of **JWKS** (JSON Web Key Sets) with caching and key rotation support.
- Support for **dependency injection** in authentication handlers and authorization requirements.
- Built-in **brute-force protection** with a configurable rate limiter for authentication attempts.
- A generic code API that works with any Python async application.

## Getting started

To get started with GuardPost, read the [_Getting Started_](./getting-started.md) guide.

To go straight to JWT validation, see [_JWT Validation_](./jwt-validation.md).

## Usage in BlackSheep

GuardPost is the built-in authentication and authorization framework in the
[BlackSheep](/blacksheep/) web framework. See [BlackSheep authentication](https://www.neoteroi.dev/blacksheep/authentication/)
and [BlackSheep authorization](https://www.neoteroi.dev/blacksheep/authorization/) for more.
