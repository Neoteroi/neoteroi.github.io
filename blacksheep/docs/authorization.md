# Authorization in BlackSheep
The words "authorization strategy" in the context of a web application refer to
the ability to determine whether the user is allowed to do certain operations.
BlackSheep implements a built-in authorization strategy for request handlers.
This page describes:

- [X] How to use the built-in authorization strategy.
- [X] How to apply authorization rules to request handlers.

It is recommended to read about [authentication](../authentication) before
reading this page.

## How to use built-in authorization

Examples of common strategies to authorize users in web applications include:

* verifying that the user's context obtained from a [JWT includes certain
  claims](https://jwt.io/introduction/) (e.g. `scope`, `role`)
* verifying that a web request includes a certain key, like an instrumentation
  key or a key signed by a private RSA key (owned by the user) that can be
  verified by a public RSA key (used by the server to validate)

The example below shows how to configure an authorization handler that
requires an authenticated user. It is modified from the example in the
[authentication](../authentication) page:

```python
from typing import Optional

from blacksheep import Application, Request, json, ok, get
from blacksheep.server.authorization import Policy, auth
from guardpost.asynchronous.authentication import AuthenticationHandler, Identity
from guardpost.authentication import User
from guardpost.common import AuthenticatedRequirement

app = Application(show_error_details=True)


class ExampleAuthHandler(AuthenticationHandler):
    def __init__(self):
        pass

    async def authenticate(self, context: Request) -> Optional[Identity]:
        header_value = context.get_first_header(b"Authorization")
        if header_value:
            # TODO: parse and validate the value of the authorization
            # header to get an actual user's identity
            context.identity = Identity({"name": "Jan Kowalski"}, "MOCK")
        else:
            context.identity = None
        return context.identity


app.use_authentication().add(ExampleAuthHandler())

Authenticated = "authenticated"

# enable authorization, and add a policy that requires an authenticated user
app.use_authorization().add(Policy(Authenticated, AuthenticatedRequirement()))


@get("/")
async def for_anybody(user: Optional[User]):
    if user is None:
        return json({"anonymous": True})

    return json(user.claims)


@auth(Authenticated)
@get("/account")
async def only_for_authenticated_users():
    return ok("example")

```

Note:

* authorization is enabled using `app.use_authorization()`
* this method returns an instance of `AuthorizationStrategy`, which handles
  the authorization rules
* the method `.add(Policy(Authenticated, AuthenticatedRequirement()))`
  configures an authorization policy with a single requirement, to have an
  authenticated user
* the authorization policy is applied to request handlers using the `@auth`
  decorator from `blacksheep.server.authorization` with an argument that
  specifies the policy to be used

It is possible to define several authorization policies, each specifying one
or more requirements to be satisfied in order for authorization to succeed.
The next example explains how to configure an authorization policy that checks
for user's roles from claims.

## Defining an authorization policy that checks a user's claims

The example below shows how to configure an authorization handler that
validates a user's claims (looking for a "role" claim that might be coming from
a JWT).

```python
from blacksheep.server.authorization import Policy

from guardpost.authorization import AuthorizationContext
from guardpost.authorization import Requirement


class AdminRequirement(Requirement):
    def handle(self, context: AuthorizationContext):
        identity = context.identity

        if identity is not None and identity.claims.get("role") == "admin":
            context.succeed(self)


class AdminsPolicy(Policy):
    def __init__(self):
        super().__init__("admin", AdminRequirement())
```

Full example:

```python
from typing import Optional

from blacksheep import Application, Request, get, json, ok
from blacksheep.server.authorization import Policy, auth
from guardpost import (
    AuthenticationHandler,
    Identity,
    User,
    AuthorizationContext,
    Requirement,
)
from guardpost.common import AuthenticatedRequirement

app = Application(show_error_details=True)


class ExampleAuthHandler(AuthenticationHandler):
    def __init__(self):
        pass

    async def authenticate(self, context: Request) -> Optional[Identity]:
        header_value = context.get_first_header(b"Authorization")
        if header_value:
            # TODO: parse and validate the value of the authorization
            # header to get an actual user's identity
            context.identity = Identity({"name": "Jan Kowalski"}, "MOCK")
        else:
            context.identity = None
        return context.identity


app.use_authentication().add(ExampleAuthHandler())

Authenticated = "authenticated"


class AdminRequirement(Requirement):
    def handle(self, context: AuthorizationContext):
        identity = context.identity

        if identity is not None and identity.claims.get("role") == "admin":
            context.succeed(self)


class AdminPolicy(Policy):
    def __init__(self):
        super().__init__("admin", AdminRequirement())


app.use_authorization().add(Policy(Authenticated, AuthenticatedRequirement())).add(
    AdminPolicy()
)


@get("/")
async def for_anybody(user: Optional[User]):
    # This method can be used by anybody
    if user is None:
        return json({"anonymous": True})

    return json(user.claims)


@auth(Authenticated)
@get("/account")
async def only_for_authenticated_users():
    # This method can be used by any authenticated user
    return ok("example")


@auth("admin")
@get("/admin")
async def only_for_administrators():
    # This method requires "admin" role in user's claims
    return ok("example")
```

## Using the default policy

The method `app.use_authorization()`, when used without arguments, returns an
instance of `AuthorizationStrategy` from the `guardpost` library. This object
can be configured to use a default policy, for example to require an
authenticated user by default for all request handlers.

```python
authorization = app.use_authorization()

# configure a default policy to require an authenticated user for all handlers
authorization.default_policy = Policy("authenticated", AuthenticatedRequirement())
```

The default policy is used when the `@auth` decorator is used without arguments.

To enable anonymous access for certain handlers in this scenario, use the
`allow_anonymous` decorator from `blacksheep.server.authorization`:

```python
from blacksheep.server.authorization import allow_anonymous


@allow_anonymous()
@get("/")
async def for_anybody(user: Optional[User]):
    if user is None:
        return json({"anonymous": True})

    return json(user.claims)
```

## Specifying authentication schemes for request handlers

In some scenarios it is necessary to specify multiple authentication schemes
for web applications: for example, the same application might handle
authentication obtained through the `GitHub` OAuth app and `Azure Active
Directory (AAD)`. In such scenarios, it might be necessary to restrict access
to some endpoints by authentication method, too.

To do so:

1. specify different authentication handlers, configuring schemes overriding
   the `scheme` property as in the example below.
2. use the `authentication_schemes` parameter in the `@auth` decorator

```python

class GitHubAuthHandler(AuthenticationHandler):

    @property
    def scheme(self) -> str:
      return "github"

    async def authenticate(self, context: Request) -> Optional[Identity]:
        ...


@auth("authenticated", authentication_schemes=["github"])
@get("/admin")
async def only_for_user_authenticated_with_github():
    # This method only tries to authenticate users using the "github"
    # authentication scheme, defined overriding the scheme @property
    return ok("example")
```

## Failure response codes

When a request fails because of authorization reasons, the web framework
returns:

- status [`401 Unauthorized`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/401) if authentication failed, and no valid credentials were provided
- status [`403 Forbidden`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/403) if
  authentication succeeded as valid credentials were provided, but the user is
  not authorized to perform an action
