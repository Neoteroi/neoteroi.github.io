# Authentication

This page describes GuardPost's authentication API in detail, covering:

- [X] The `AuthenticationHandler` abstract class
- [X] Synchronous vs asynchronous `authenticate` methods
- [X] The `scheme` property
- [X] The `Identity` class and its claims
- [X] The `AuthenticationStrategy` class
- [X] Using multiple handlers
- [X] Grouping handlers by scheme

## The `AuthenticationHandler` abstract class

`AuthenticationHandler` is the base class for all authentication logic. Subclass
it and implement the `authenticate` method to read credentials from a context
and, when valid, set `context.identity`.

```python {linenums="1"}
from guardpost import AuthenticationHandler, Identity


class MyHandler(AuthenticationHandler):
    async def authenticate(self, context) -> None:
        # Read credentials from context, validate them, then:
        context.identity = Identity(claims={"sub": "user-1"}, scheme="Bearer")
```

The `context` parameter is whatever your application uses to represent a
request — GuardPost imposes no specific type on it. In
[BlackSheep](https://www.neoteroi.dev/blacksheep/) this is the `Request`
object; in other frameworks it could be any object you choose.

## Synchronous vs asynchronous handlers

Both sync and async implementations are supported:

=== "Async"

    ```python {linenums="1"}
    from guardpost import AuthenticationHandler, Identity


    class AsyncBearerHandler(AuthenticationHandler):
        scheme = "Bearer"

        async def authenticate(self, context) -> None:
            token = getattr(context, "token", None)
            if token:
                # e.g. validate token against a remote service
                user_info = await fetch_user_info(token)
                if user_info:
                    context.identity = Identity(
                        claims=user_info, scheme=self.scheme
                    )
    ```

=== "Sync"

    ```python {linenums="1"}
    from guardpost import AuthenticationHandler, Identity


    class SyncApiKeyHandler(AuthenticationHandler):
        scheme = "ApiKey"

        _valid_keys = {"key-abc": "service-a", "key-xyz": "service-b"}

        def authenticate(self, context) -> None:
            api_key = getattr(context, "api_key", None)
            sub = self._valid_keys.get(api_key)
            if sub:
                context.identity = Identity(
                    claims={"sub": sub}, scheme=self.scheme
                )
    ```

## The `scheme` property

The optional `scheme` class property names the authentication scheme this
handler implements (e.g. `"Bearer"`, `"ApiKey"`, `"Cookie"`). Naming
schemes is useful when multiple handlers are registered and you need to
identify which one authenticated a request.

```python {linenums="1"}
from guardpost import AuthenticationHandler, Identity


class CookieHandler(AuthenticationHandler):
    scheme = "Cookie"

    async def authenticate(self, context) -> None:
        session_id = getattr(context, "session_id", None)
        if session_id:
            context.identity = Identity(
                claims={"sub": "user-from-cookie"}, scheme=self.scheme
            )
```

## The `Identity` class and its claims

`Identity` wraps a `dict` of claims and a `scheme` string.

```python {linenums="1"}
from guardpost import Identity

identity = Identity(
    claims={
        "sub": "user-42",
        "name": "Bob",
        "email": "bob@example.com",
        "roles": ["editor"],
        "iss": "https://auth.example.com",
    },
    scheme="Bearer",
)

# Convenience properties
print(identity.sub)           # "user-42"
print(identity.name)          # "Bob"
print(identity.access_token)  # None — not set

# Dict-style access
print(identity["email"])      # "bob@example.com"
print(identity.get("roles"))  # ["editor"]

# Scheme
print(identity.scheme)        # "Bearer"

# Authentication check
print(identity.is_authenticated())  # True
print(Identity.is_authenticated())  # False (class method, no instance)
```

/// admonition | `None` means unauthenticated
    type: info

`context.identity` starts as `None`. A handler only sets it when authentication
succeeds. Code that needs an authenticated user should check `context.identity`
before proceeding, or rely on `AuthorizationStrategy` which raises
`UnauthorizedError` automatically when the identity is `None`.
///

## The `AuthenticationStrategy` class

`AuthenticationStrategy` manages a list of handlers and calls them in sequence.
Once a handler sets `context.identity`, the remaining handlers are skipped.

```python {linenums="1"}
import asyncio
from guardpost import AuthenticationHandler, AuthenticationStrategy, Identity


class MockContext:
    def __init__(self, token=None, api_key=None):
        self.token = token
        self.api_key = api_key
        self.identity = None


class BearerHandler(AuthenticationHandler):
    scheme = "Bearer"

    async def authenticate(self, context) -> None:
        if context.token == "valid-jwt":
            context.identity = Identity(
                claims={"sub": "u1", "name": "Alice"}, scheme=self.scheme
            )


class ApiKeyHandler(AuthenticationHandler):
    scheme = "ApiKey"

    def authenticate(self, context) -> None:
        if context.api_key == "svc-key":
            context.identity = Identity(
                claims={"sub": "service-a"}, scheme=self.scheme
            )


async def main():
    strategy = AuthenticationStrategy(BearerHandler(), ApiKeyHandler())

    ctx = MockContext(api_key="svc-key")
    await strategy.authenticate(ctx)
    print(ctx.identity.sub)     # "service-a"
    print(ctx.identity.scheme)  # "ApiKey"


asyncio.run(main())
```

## Using multiple handlers

When multiple handlers are registered, they are tried in the order they are
passed to `AuthenticationStrategy`. The first handler to set `context.identity`
wins; subsequent handlers are not called.

```python {linenums="1", hl_lines="3-4"}
strategy = AuthenticationStrategy(
    JWTHandler(),      # tried first
    ApiKeyHandler(),   # tried second, only if JWT handler didn't set identity
    CookieHandler(),   # tried third, only if both above didn't set identity
)
```

This is useful for APIs that support multiple credential types simultaneously.

## Grouping handlers by scheme

You can inspect `context.identity.scheme` after authentication to know which
handler authenticated the request, and apply different logic accordingly.

```python {linenums="1"}
import asyncio
from guardpost import AuthenticationHandler, AuthenticationStrategy, Identity


class MockContext:
    def __init__(self, token=None, api_key=None):
        self.token = token
        self.api_key = api_key
        self.identity = None


class BearerHandler(AuthenticationHandler):
    scheme = "Bearer"

    async def authenticate(self, context) -> None:
        if context.token:
            context.identity = Identity(
                claims={"sub": "user-1"}, scheme=self.scheme
            )


class ApiKeyHandler(AuthenticationHandler):
    scheme = "ApiKey"

    def authenticate(self, context) -> None:
        if context.api_key:
            context.identity = Identity(
                claims={"sub": "svc-1"}, scheme=self.scheme
            )


async def handle_request(context):
    strategy = AuthenticationStrategy(BearerHandler(), ApiKeyHandler())
    await strategy.authenticate(context)

    if context.identity is None:
        print("Anonymous request")
    elif context.identity.scheme == "Bearer":
        print(f"Human user: {context.identity.sub}")
    elif context.identity.scheme == "ApiKey":
        print(f"Service call: {context.identity.sub}")


asyncio.run(handle_request(MockContext(api_key="any-key")))
# Service call: svc-1
```
