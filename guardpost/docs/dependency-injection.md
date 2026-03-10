# Dependency Injection

This page covers how GuardPost supports dependency injection in authentication
handlers and authorization requirements, including:

- [X] Why DI is useful in auth handlers and requirements
- [X] Declaring injected dependencies as class properties
- [X] Passing a `container` to `AuthorizationStrategy`
- [X] Using `rodi` as the DI container
- [X] Example: injecting a database service into a `Requirement`
- [X] Example: injecting a service into an `AuthenticationHandler`

## Why dependency injection in auth?

Authentication handlers and authorization requirements often need external
services — database connections, caches, configuration objects — to do their
work. Without DI you'd have to pass these services manually through constructors
or global singletons.

GuardPost integrates with dependency injection containers so that your handlers
and requirements can declare their dependencies as class properties, letting the
container wire them up automatically.

/// admonition | GuardPost works with any DI container
    type: info

GuardPost uses a generic `container` protocol. Any container that implements a
`resolve(type)` method works. [Rodi](https://www.neoteroi.dev/rodi/) is the
recommended container and is used throughout the examples below.
///

## Declaring injected dependencies

Declare dependencies as **class-level type-annotated properties**. GuardPost
inspects these annotations and asks the container to provide instances when
the handler or requirement is invoked.

```python {linenums="1"}
from guardpost.authorization import AuthorizationContext, Requirement


class UserRepository:
    async def get_permissions(self, user_id: str) -> list[str]:
        # Simulate a DB lookup
        return ["read", "write"] if user_id == "u1" else ["read"]


class HasPermissionRequirement(Requirement):
    # Declare the dependency — the container will inject this
    user_repository: UserRepository

    def __init__(self, permission: str) -> None:
        self._permission = permission

    async def handle(self, context: AuthorizationContext) -> None:
        permissions = await self.user_repository.get_permissions(
            context.identity.sub
        )
        if self._permission in permissions:
            context.succeed(self)
        else:
            context.fail(f"Missing permission: {self._permission!r}")
```

## Passing a container to `AuthorizationStrategy`

Pass the DI container as the `container` keyword argument when constructing
`AuthorizationStrategy`:

```python {linenums="1"}
import rodi
from guardpost.authorization import AuthorizationStrategy, Policy

from myapp.requirements import HasPermissionRequirement
from myapp.repositories import UserRepository

container = rodi.Container()
container.register(UserRepository)

strategy = AuthorizationStrategy(
    Policy("write", HasPermissionRequirement("write")),
    container=container,
)
```

When `authorize` is called, GuardPost resolves `UserRepository` from the
container and injects it into `HasPermissionRequirement` before calling
`handle`.

## Full example: injecting a database service into a `Requirement`

```python {linenums="1"}
import asyncio
import rodi
from guardpost import Identity
from guardpost.authorization import (
    AuthorizationContext,
    AuthorizationStrategy,
    Policy,
    Requirement,
)


# --- Services ---

class PermissionsDB:
    """Simulates a database of user permissions."""

    async def get_permissions(self, user_id: str) -> list[str]:
        await asyncio.sleep(0)  # would be a real DB call
        data = {
            "u1": ["read", "write", "delete"],
            "u2": ["read"],
        }
        return data.get(user_id, [])


# --- Requirement ---

class HasPermissionRequirement(Requirement):
    permissions_db: PermissionsDB  # injected by the container

    def __init__(self, permission: str) -> None:
        self._permission = permission

    async def handle(self, context: AuthorizationContext) -> None:
        perms = await self.permissions_db.get_permissions(context.identity.sub)
        if self._permission in perms:
            context.succeed(self)
        else:
            context.fail(f"Permission '{self._permission}' not granted.")


# --- Wiring ---

async def main():
    container = rodi.Container()
    container.register(PermissionsDB)

    strategy = AuthorizationStrategy(
        Policy("delete", HasPermissionRequirement("delete")),
        container=container,
    )

    power_user = Identity(claims={"sub": "u1"}, authentication_mode="Bearer")
    await strategy.authorize("delete", power_user)
    print("Authorized ✔")

    from guardpost.authorization import ForbiddenError

    basic_user = Identity(claims={"sub": "u2"}, authentication_mode="Bearer")
    try:
        await strategy.authorize("delete", basic_user)
    except ForbiddenError as exc:
        print(f"Forbidden: {exc}")


asyncio.run(main())
```

## Full example: injecting a service into an `AuthenticationHandler`

Authentication handlers can also receive injected services. Declare them as
class properties in the same way:

```python {linenums="1"}
import asyncio
import rodi
from guardpost import AuthenticationHandler, AuthenticationStrategy, Identity
from guardpost.protection import InvalidCredentialsError


# --- Service ---

class UserStore:
    """Simulates a user store."""

    async def find_by_api_key(self, api_key: str) -> dict | None:
        await asyncio.sleep(0)
        store = {"key-abc": {"sub": "svc-a"}, "key-xyz": {"sub": "svc-b"}}
        return store.get(api_key)


# --- Handler ---

class ApiKeyHandler(AuthenticationHandler):
    scheme = "ApiKey"
    user_store: UserStore  # injected

    async def authenticate(self, context) -> None:
        api_key = getattr(context, "api_key", None)
        if not api_key:
            return  # no credentials — anonymous, don't count as failure
        user = await self.user_store.find_by_api_key(api_key)
        if user:
            context.identity = Identity(claims=user, scheme=self.scheme)
        else:
            raise InvalidCredentialsError("Unknown API key.")


# --- Wiring ---

class MockContext:
    def __init__(self, api_key=None):
        self.api_key = api_key
        self.identity = None


async def main():
    container = rodi.Container()
    container.register(UserStore)

    strategy = AuthenticationStrategy(
        ApiKeyHandler(),
        container=container,
    )

    ctx = MockContext(api_key="key-abc")
    await strategy.authenticate(ctx)
    print(ctx.identity.sub)  # "svc-a"


asyncio.run(main())
```

/// admonition | Constructor injection vs property injection
    type: tip

GuardPost uses **property injection** (class-level type annotations). This is
consistent with how [Rodi](https://www.neoteroi.dev/rodi/) works and avoids
needing to change handler constructors. Dependencies are resolved fresh for
each invocation when the container is configured for transient or scoped
lifetimes.
///
