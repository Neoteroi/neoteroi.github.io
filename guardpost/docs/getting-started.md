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
principal. It carries a dict of **claims** and an **authentication_mode** string that
indicates how the identity was authenticated.

```python {linenums="1"}
from guardpost import Identity

# Create an identity with claims
identity = Identity(
    {
        "sub": "user-123",
        "name": "Alice",
        "email": "alice@example.com",
        "roles": ["admin", "editor"],
    },
    "Bearer",
)

print(identity.sub)          # "user-123"
print(identity.name)         # "Alice"
print(identity["email"])     # "alice@example.com" — dict-style access
print(identity.is_authenticated())  # True — authentication_mode is set

# An Identity with no authentication_mode is anonymous (unauthenticated)
anon = Identity({"sub": "guest"})
print(anon.is_authenticated())  # False
```

/// admonition | Anonymous vs unauthenticated
    type: info

`Identity.is_authenticated()` returns `True` only when `authentication_mode` is set
to a non-empty string. An `Identity` created without `authentication_mode` (or with
`authentication_mode=None`) is treated as **anonymous** — it carries claims but is
not considered authenticated. `context.identity` being `None` means no identity was
resolved at all.
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
                {"sub": "user-1", "name": "Alice"},
                self.scheme,
            )
        # If the token is missing or wrong you can leave context.identity as None,
        # or leave authentication_mode unset to create an anonymous identity
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
                {"sub": "user-1", "name": "Alice"},
                self.scheme,
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
        {"sub": "u1", "roles": ["admin"]}, "Bearer"
    )
    await strategy.authorize("admin", admin_identity)
    print("Admin authorized ✔")

    # --- Regular user: forbidden ---
    from guardpost.authorization import ForbiddenError

    user_identity = Identity(
        {"sub": "u2", "roles": ["viewer"]}, "Bearer"
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
