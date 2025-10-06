# Authorization in BlackSheep

The term 'authorization strategy' in the context of a web application refers to
the process of determining whether a user is permitted to perform certain operations.
BlackSheep provides a built-in authorization strategy for request handlers.
This page covers:

- [X] How to use the built-in authorization strategy.
- [X] How to apply authorization rules to request handlers.
- [X] How to require roles in request handlers.

It is recommended to review the [authentication documentation](authentication.md)
before proceeding with this page.

## How to use built-in authorization

Common strategies for authorizing users in web applications include:

* Verifying that the user's context, obtained from a [JWT](https://jwt.io/introduction/),
  includes certain claims (e.g., `scope`, `role`)
* Verifying that a web request contains a specific key, such as an
  instrumentation key or a key signed by a private RSA key (owned by the user)
  and validated by a public RSA key (used by the server).

The following example demonstrates how to configure an authorization handler
that requires an authenticated user. It is adapted from the example on the
[authentication's documentation](authentication.md) page:

```python {hl_lines="17-24 27 32 43"}
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

* Authorization is enabled by calling `app.use_authorization()`. This method
  returns an instance of `AuthorizationStrategy`, which manages the
  authorization rules.
* The method `.add(Policy(Authenticated, AuthenticatedRequirement()))`
  configures an authorization policy with a single requirement, to have an
  authenticated user.
* The authorization policy is applied to request handlers using the `@auth`
  decorator from `blacksheep.server.authorization` with an argument that
  specifies the policy to be used.

It is possible to define several authorization policies, each specifying one
or more requirements to be satisfied in order for authorization to succeed.

## Defining an authorization policy that checks claims

The following example demonstrates how to configure an authorization handler
that validates a user's claims, such as checking for a `role` claim that may
originate from a JWT.

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

The `app.use_authorization()` method returns an instance of
`AuthorizationStrategy` from the `guardpost` library. This object can be
configured to use a default policy, such as requiring an authenticated user by
default for all request handlers.

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
authentication obtained through the `GitHub` OAuth app and `Microsoft Entra ID`.
In such scenarios, it might be necessary to restrict access to some endpoints
by authentication method, too.

To do so:

1. Specify different authentication handlers, configuring schemes overriding
   the `scheme` property as in the example below.
2. Use the `authentication_schemes` parameter in the `@auth` decorator.

```python {hl_lines="1 3-5 11"}
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

## Authorizing by roles

/// tab | Since version 2.4.2

Since version `2.4.2`, the framework includes built-in features to require
_sufficient_ roles (any one is enough) to authorize web requests. The authenticated
user object must have a `roles` property of type `List[str]`.

```python
from blacksheep.server.authorization import Policy, auth


app.use_authentication(...)  # configure as desired


# requires a user with a roles property containing the string "admin" ↓
@auth(roles=["admin"])
async def only_for_admins():
    ...
```

Examples:

- When using JWT Bearer authentication, the JWT payload must have a `roles` claim with
  the desired roles, for authorization to succeed.
- When using Basic authentication or API Key authentication with the built-in classes,
  refer to the documentation at [_Authentication_](./authentication.md) for examples
  on how to configure roles or claims on the identity object obtained after successful
  authentication.
- When using custom authentication handlers, implement the desired logic and configure
  `Identity` objects with the desired roles.

```python
class MyAuthenticationHandler(AuthenticationHandler):
    def authenticate(self, context: Request) -> Identity | None:
        # TODO: implement your own authentication logic, handle roles as desired
        return Identity({"sub": "***", "roles": []}, self.scheme)
```

///

/// tab | Before version 2.4.2

Before `2.4.2`, the framework did not include any specific code to define
roles for authorization, and required defining a _Policy_ that would
check for the desired property on the request context.

```python
from guardpost import (
    AuthenticationHandler,
    Identity,
    User,
    AuthorizationContext,
    Requirement,
)
from guardpost.common import AuthenticatedRequirement


class AdminRequirement(Requirement):
    def handle(self, context: AuthorizationContext):
        identity = context.identity

        # Your own logic to check identity claims…
        if identity is not None and identity.claims.get("role") == "admin":
            context.succeed(self)

app.use_authentication(...)  # configure as desired

app.use_authorization().add(Policy("admin", AdminRequirement()))

@auth("admin")
async def only_for_admins():
    ...
```

///

## Failure response codes

When a request fails because of authorization reasons, the web framework
returns:

- Status [`401
  Unauthorized`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/401)
  if authentication failed and no valid credentials were provided.
- Status [`403 Forbidden`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/403) if
  authentication succeeded as valid credentials were provided, but the user is
  not authorized to perform an action.


## Dependency Injection in authorization requirements

Dependency Injection is supported in authorization code. To use it:

1. Configure `Requirement` objects as types (not instances)
   associated to the policies of the `AuthorizationStrategy` object.
2. Register dependencies in the DI container, and in the handler classes
   according to the solution you are using for dependency injection.

The code below illustrates and example using the built-in solution for DI.

```python {linenums="1" hl_lines="13-14 17-18 21 41-42 45-46"}
from blacksheep import Application, Request, json
from guardpost import (
    AuthenticationHandler,
    AuthorizationContext,
    Identity,
    Policy,
    Requirement,
)

app = Application(show_error_details=True)


class ExampleDependency:
    pass


class MyInjectedRequirement(Requirement):
    dependency: ExampleDependency

    def handle(self, context: AuthorizationContext):  # Note: this can also be async!
        assert isinstance(self.dependency, ExampleDependency)
        #
        # TODO: implement here the authorization logic
        #
        roles = context.identity.claims.get("roles", [])
        if roles and "ADMIN" in roles:
            context.succeed(self)
        else:
            context.fail("The user is not an ADMIN")


class MyAuthenticationHandler(AuthenticationHandler):
    def authenticate(self, context: Request) -> Identity | None:
        # TODO: implement your own authentication logic
        return Identity({"id": "example", "sub": "001", "roles": []}, self.scheme)


authentication = app.use_authentication()
authentication.add(MyAuthenticationHandler)

authorization = app.use_authorization()
authorization.with_default_policy(Policy("default", MyInjectedRequirement))

# We need to register the types in the DI container!
app.services.register(MyInjectedRequirement)
app.services.register(ExampleDependency)
app.services.register(MyAuthenticationHandler)


@app.router.get("/")
def home(request: Request):
    assert request.user is not None
    return json(request.user.claims)
```

/// admonition | ContainerProtocol.
    type: tip

As documented in [_Container Protocol_](./dependency-injection.md#the-container-protocol), BlackSheep
supports the use of other DI containers as replacements for the built-in
library used for dependency injection.

///
