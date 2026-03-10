# Getting started with GuardPost

This page introduces the basics of using GuardPost, including:

- [X] Installing GuardPost
- [X] The `Identity` class
- [X] Implementing a simple `AuthenticationHandler`
- [X] Using `AuthenticationStrategy`
- [X] Implementing a `Requirement` and `Policy`
- [X] Using `AuthorizationStrategy`
- [X] Handling authentication and authorization errors

## Installation

```shell
pip install guardpost
```

For JWT validation support, install the optional extra:

```shell
pip install guardpost[jwt]
```

## The `Identity` class

An `Identity` represents the authenticated entity — a user, a service, or any
principal. It carries a dict of **claims** and a **scheme** string that
indicates how the identity was authenticated.

```python {linenums="1"}
from guardpost import Identity

# Create an identity with claims
identity = Identity(
    claims={
        "sub": "user-123",
        "name": "Alice",
        "email": "alice@example.com",
        "roles": ["admin", "editor"],
    },
    scheme="Bearer",
)

print(identity.sub)          # "user-123"
print(identity.name)         # "Alice"
print(identity["email"])     # "alice@example.com" — dict-style access
print(identity.is_authenticated())  # True

# An identity with no claims is still truthy, but conventionally
# a None identity means "not authenticated"
```

/// admonition | Unauthenticated identity
    type: info

By convention, `None` represents an unauthenticated request. `Identity.is_authenticated()`
returns `True` for any non-`None` identity instance, regardless of its claims.
///

## Implementing an `AuthenticationHandler`

An `AuthenticationHandler` reads credentials from a context object and, if
valid, sets `context.identity`.

```python {linenums="1"}
from guardpost import AuthenticationHandler, Identity


class MockContext:
    """A minimal context object — in real apps this might be an HTTP request."""
    def __init__(self, token: str | None = None):
        self.token = token
        self.identity: Identity | None = None


class BearerTokenHandler(AuthenticationHandler):
    """Authenticates requests that carry a hard-coded bearer token."""

    scheme = "Bearer"

    async def authenticate(self, context: MockContext) -> None:
        token = context.token
        if token == "secret-token":
            context.identity = Identity(
                claims={"sub": "user-1", "name": "Alice"},
                scheme=self.scheme,
            )
        # If the token is missing or wrong we simply leave context.identity as None
```

/// admonition | Synchronous handlers
    type: tip

`authenticate` can be either `async def` or a plain `def` — GuardPost
handles both transparently.
///

## Using `AuthenticationStrategy`

`AuthenticationStrategy` coordinates one or more handlers, calling them in
order until one sets `context.identity`.

```python {linenums="1"}
import asyncio
from guardpost import AuthenticationHandler, AuthenticationStrategy, Identity


class MockContext:
    def __init__(self, token: str | None = None):
        self.token = token
        self.identity: Identity | None = None


class BearerTokenHandler(AuthenticationHandler):
    scheme = "Bearer"

    async def authenticate(self, context: MockContext) -> None:
        if context.token == "secret-token":
            context.identity = Identity(
                claims={"sub": "user-1", "name": "Alice"},
                scheme=self.scheme,
            )


async def main():
    strategy = AuthenticationStrategy(BearerTokenHandler())

    # --- Happy path ---
    ctx = MockContext(token="secret-token")
    await strategy.authenticate(ctx)
    print(ctx.identity)          # Identity object
    print(ctx.identity.name)     # "Alice"

    # --- Unknown token ---
    ctx2 = MockContext(token="wrong-token")
    await strategy.authenticate(ctx2)
    print(ctx2.identity)         # None


asyncio.run(main())
```

## Implementing a `Requirement` and `Policy`

A `Requirement` encodes a single authorization rule. A `Policy` groups a name
with one or more requirements — all must succeed for the policy to pass.

```python {linenums="1"}
from guardpost import Identity
from guardpost.authorization import (
    AuthorizationContext,
    Policy,
    Requirement,
)


class AdminRequirement(Requirement):
    """Allows only identities that carry the 'admin' role."""

    async def handle(self, context: AuthorizationContext) -> None:
        identity = context.identity
        roles = identity.get("roles", [])
        if "admin" in roles:
            context.succeed(self)
        else:
            context.fail("User does not have the 'admin' role.")


# A policy named "admin" that requires AdminRequirement to pass
admin_policy = Policy("admin", AdminRequirement())
```

## Using `AuthorizationStrategy`

```python {linenums="1"}
import asyncio
from guardpost import Identity
from guardpost.authorization import (
    AuthorizationContext,
    AuthorizationStrategy,
    Policy,
    Requirement,
)


class AdminRequirement(Requirement):
    async def handle(self, context: AuthorizationContext) -> None:
        roles = context.identity.get("roles", [])
        if "admin" in roles:
            context.succeed(self)
        else:
            context.fail("User does not have the 'admin' role.")


async def main():
    strategy = AuthorizationStrategy(
        Policy("admin", AdminRequirement()),
    )

    # --- Admin user: authorized ---
    admin_identity = Identity(
        claims={"sub": "u1", "roles": ["admin"]}, scheme="Bearer"
    )
    await strategy.authorize("admin", admin_identity)
    print("Admin authorized ✔")

    # --- Regular user: forbidden ---
    from guardpost.authorization import ForbiddenError

    user_identity = Identity(
        claims={"sub": "u2", "roles": ["viewer"]}, scheme="Bearer"
    )
    try:
        await strategy.authorize("admin", user_identity)
    except ForbiddenError as e:
        print(f"Forbidden: {e}")


asyncio.run(main())
```

## Handling errors

GuardPost raises specific exceptions for authentication and authorization failures.

```python {linenums="1"}
import asyncio
from guardpost import UnauthenticatedError
from guardpost.authorization import (
    AuthorizationStrategy,
    ForbiddenError,
    Policy,
    Requirement,
    AuthorizationContext,
)


class AuthenticatedRequirement(Requirement):
    async def handle(self, context: AuthorizationContext) -> None:
        context.succeed(self)


async def main():
    strategy = AuthorizationStrategy(
        Policy("authenticated", AuthenticatedRequirement()),
    )

    # Passing None as identity raises UnauthorizedError
    from guardpost.authorization import UnauthorizedError

    try:
        await strategy.authorize("authenticated", None)
    except UnauthorizedError:
        print("Not authenticated — must log in first.")

    # A valid identity that fails a requirement raises ForbiddenError
    # (see full example in the Authorization page)


asyncio.run(main())
```

/// admonition | Error hierarchy
    type: info

`UnauthorizedError` means the user is not authenticated (no identity).
`ForbiddenError` means the user is authenticated but lacks the required
permissions. Both are subclasses of `AuthorizationError`.
///
