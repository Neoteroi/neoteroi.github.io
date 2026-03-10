# Authorization

This page describes GuardPost's authorization API in detail, covering:

- [X] The `Requirement` abstract class
- [X] The `AuthorizationContext` class
- [X] The `Policy` class
- [X] The `AuthorizationStrategy` class
- [X] Multiple requirements per policy
- [X] `UnauthorizedError` vs `ForbiddenError`
- [X] `AuthorizationError` base class
- [X] Async requirements

## The `Requirement` abstract class

A `Requirement` encodes a single authorization rule. Subclass it and implement
the `handle` method, then call `context.succeed(self)` if the rule passes or
`context.fail(message)` if it does not.

```python {linenums="1"}
from guardpost.authorization import AuthorizationContext, Requirement


class AuthenticatedRequirement(Requirement):
    """Passes for any authenticated identity."""

    async def handle(self, context: AuthorizationContext) -> None:
        # context.identity is guaranteed non-None at this point
        context.succeed(self)
```

/// admonition | `handle` can be sync or async
    type: tip

Like `AuthenticationHandler.authenticate`, the `handle` method can be either
`async def` or a plain `def`. GuardPost calls it correctly in both cases.
///

## The `AuthorizationContext` class

`AuthorizationContext` is passed to every requirement and carries:

| Attribute / method | Description |
|--------------------|-------------|
| `.identity` | The current `Identity` (never `None` inside a requirement) |
| `.succeed(requirement)` | Mark the given requirement as satisfied |
| `.fail(message)` | Fail the entire authorization check with an optional message |

```python {linenums="1"}
from guardpost import Identity
from guardpost.authorization import AuthorizationContext, Requirement


class RoleRequirement(Requirement):
    def __init__(self, role: str) -> None:
        self._role = role

    async def handle(self, context: AuthorizationContext) -> None:
        roles = context.identity.get("roles", [])
        if self._role in roles:
            context.succeed(self)
        else:
            context.fail(f"Identity does not have role '{self._role}'.")
```

## The `Policy` class

A `Policy` pairs a **name** with one or more `Requirement` objects. All
requirements must succeed for the policy to pass.

```python {linenums="1"}
from guardpost.authorization import Policy, Requirement, AuthorizationContext


class AdminRequirement(Requirement):
    async def handle(self, context: AuthorizationContext) -> None:
        if "admin" in context.identity.get("roles", []):
            context.succeed(self)
        else:
            context.fail("Admin role required.")


class ActiveAccountRequirement(Requirement):
    async def handle(self, context: AuthorizationContext) -> None:
        if context.identity.get("active", False):
            context.succeed(self)
        else:
            context.fail("Account is not active.")


# Both AdminRequirement AND ActiveAccountRequirement must succeed
admin_policy = Policy("admin", AdminRequirement(), ActiveAccountRequirement())
```

## The `AuthorizationStrategy` class

`AuthorizationStrategy` holds a collection of policies and exposes
`authorize(policy_name, identity)`. It raises an error when authorization
fails and returns normally when it succeeds.

```python {linenums="1"}
import asyncio
from guardpost import Identity
from guardpost.authorization import (
    AuthorizationStrategy,
    AuthorizationContext,
    ForbiddenError,
    Policy,
    Requirement,
    UnauthorizedError,
)


class AdminRequirement(Requirement):
    async def handle(self, context: AuthorizationContext) -> None:
        if "admin" in context.identity.get("roles", []):
            context.succeed(self)
        else:
            context.fail("Admin role required.")


async def main():
    strategy = AuthorizationStrategy(
        Policy("admin", AdminRequirement()),
    )

    # Happy path — admin user
    admin = Identity(claims={"sub": "u1", "roles": ["admin"]}, scheme="Bearer")
    await strategy.authorize("admin", admin)
    print("Authorized ✔")

    # ForbiddenError — authenticated but lacks role
    viewer = Identity(claims={"sub": "u2", "roles": ["viewer"]}, scheme="Bearer")
    try:
        await strategy.authorize("admin", viewer)
    except ForbiddenError as exc:
        print(f"Forbidden: {exc}")

    # UnauthorizedError — not authenticated at all
    try:
        await strategy.authorize("admin", None)
    except UnauthorizedError:
        print("Unauthorized — must log in.")


asyncio.run(main())
```

## Multiple requirements per policy

When a policy declares multiple requirements, **every one** must call
`context.succeed(self)` for the policy to pass. If any requirement calls
`context.fail(...)` the check stops immediately.

```python {linenums="1", hl_lines="20-21"}
import asyncio
from guardpost import Identity
from guardpost.authorization import (
    AuthorizationStrategy,
    AuthorizationContext,
    ForbiddenError,
    Policy,
    Requirement,
)


class HasRoleRequirement(Requirement):
    def __init__(self, role: str) -> None:
        self._role = role

    async def handle(self, context: AuthorizationContext) -> None:
        if self._role in context.identity.get("roles", []):
            context.succeed(self)
        else:
            context.fail(f"Missing role: {self._role!r}")


class EmailVerifiedRequirement(Requirement):
    async def handle(self, context: AuthorizationContext) -> None:
        if context.identity.get("email_verified"):
            context.succeed(self)
        else:
            context.fail("Email address not verified.")


async def main():
    strategy = AuthorizationStrategy(
        Policy(
            "verified-editor",
            HasRoleRequirement("editor"),
            EmailVerifiedRequirement(),
        )
    )

    ok_identity = Identity(
        claims={"sub": "u1", "roles": ["editor"], "email_verified": True},
        scheme="Bearer",
    )
    await strategy.authorize("verified-editor", ok_identity)
    print("Authorized ✔")

    bad_identity = Identity(
        claims={"sub": "u2", "roles": ["editor"], "email_verified": False},
        scheme="Bearer",
    )
    try:
        await strategy.authorize("verified-editor", bad_identity)
    except ForbiddenError as exc:
        print(f"Forbidden: {exc}")  # "Email address not verified."


asyncio.run(main())
```

## `UnauthorizedError` vs `ForbiddenError`

| Exception | When raised |
|-----------|-------------|
| `UnauthorizedError` | `identity` is `None` — the request is unauthenticated |
| `ForbiddenError` | `identity` is set but a requirement called `context.fail()` |

Both are subclasses of `AuthorizationError`.

```python {linenums="1"}
from guardpost.authorization import (
    AuthorizationError,
    ForbiddenError,
    UnauthorizedError,
)

try:
    await strategy.authorize("admin", identity)
except UnauthorizedError:
    # Return HTTP 401 — please authenticate
    ...
except ForbiddenError:
    # Return HTTP 403 — authenticated but not allowed
    ...
except AuthorizationError:
    # Catch-all for any other authorization failure
    ...
```

## `AuthorizationError` base class

`AuthorizationError` is the common base class for all authorization
exceptions. Catch it when you want to handle any authorization failure
without distinguishing between the specific subtypes.

## Async requirements

Requirements can perform async operations — such as querying a database or
calling an external service — directly in their `handle` method.

```python {linenums="1"}
import asyncio
from guardpost import Identity
from guardpost.authorization import AuthorizationContext, Requirement


async def fetch_user_permissions(user_id: str) -> list[str]:
    """Simulates an async database lookup."""
    await asyncio.sleep(0)  # real code would await a DB call here
    return ["read", "write"] if user_id == "u1" else ["read"]


class PermissionRequirement(Requirement):
    def __init__(self, permission: str) -> None:
        self._permission = permission

    async def handle(self, context: AuthorizationContext) -> None:
        user_id = context.identity.sub
        permissions = await fetch_user_permissions(user_id)
        if self._permission in permissions:
            context.succeed(self)
        else:
            context.fail(f"Missing permission: {self._permission!r}")
```
