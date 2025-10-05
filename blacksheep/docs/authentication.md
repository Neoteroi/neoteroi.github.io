# Authentication in BlackSheep

The term 'authentication strategy' in the context of a web application refers
to the process of identifying the user accessing the application. BlackSheep
provides a built-in authentication strategy for request handlers. This page
covers:

- [X] How to use the built-in authentication strategy.
- [X] How to configure a custom authentication handler.
- [X] How to use the built-in support for **API Key** authentication.
- [X] How to use the built-in support for **Basic authentication**.
- [X] How to use the built-in support for **JWT Bearer** authentication.
- [X] How to read the user's context in request handlers.

## How to use built-in authentication

Common strategies for identifying users in web applications include:

- Reading an `Authorization: Bearer xxx` request header containing a [JWT](https://jwt.io/introduction/).
  with claims that identify the user.
- Reading a signed token from a cookie.

The following sections first explain how to use the built-in support for JWT
Bearer tokens and then describe how to write a custom authentication handler.

/// admonition | Terms: user, service, principal.

The term 'user' typically refers to human users, while 'service' describes
non-human clients. In Java and .NET, the term 'principal' is commonly used to
describe a generic identity.

///

## API Key authentication

The following example illustrates how API Key authentication can be enabled
in BlackSheep:

```python
from blacksheep import Application, get
from blacksheep.server.authentication.apikey import APIKey, APIKeyAuthentication
from blacksheep.server.authorization import auth
from essentials.secrets import Secret


app = Application()


app.use_authentication().add(
    APIKeyAuthentication(
        APIKey(
            secret=Secret("$API_SECRET"),  # ⟵ obtained from API_SECRET env var
            roles=["user"],  # ⟵ optional roles
        ),
        param_name="X-API-Key",
    )
)

app.use_authorization()


@auth()  # requires authorization
@get("/")
async def get_claims(request):
    return request.user.roles
```

## Basic authentication

```python
from blacksheep import Application, get
from blacksheep.server.authentication.basic import BasicAuthentication, BasicCredentials
from blacksheep.server.authorization import auth
from essentials.secrets import Secret


app = Application()


admin_credentials =

print(admin_credentials.to_header_value())

app.use_authentication().add(
    BasicAuthentication(
        BasicCredentials(
            username="admin",
            password=Secret("$ADMIN_PASSWORD"),  # ⟵ obtained from ADMIN_PASSWORD env var
            roles=["admin"],  # ⟵ optional roles
        ),
        BasicCredentials(
            username="user",
            password=Secret("$USER_PASSWORD"),  # ⟵ obtained from USER_PASSWORD env var
            roles=["user"],  # ⟵ optional roles
        )
    )
)

app.use_authorization()


@auth()  # requires authorization
@get("/")
async def get_claims(request):
    return request.user.roles
```


## OIDC

BlackSheep implements built-in support for OpenID Connect authentication,
meaning that it can be easily integrated with identity provider services such
as:

- [Auth0](https://auth0.com).
- [Entra ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id).
- [Azure Active Directory B2C](https://docs.microsoft.com/en-us/azure/active-directory-b2c/overview).
- [Okta](https://www.okta.com).

/// admonition | Examples in GitHub.
    type: tip

The [Neoteroi/BlackSheep-Examples/](https://github.com/Neoteroi/BlackSheep-Examples/)
repository in GitHub contains examples of JWT Bearer authentication and OpenID
Connect integrations.

///

A basic example of integration with any of the identity providers listed above,
using implicit flow for `id_token` (which removes the need to handle secrets),
is shown below:

```python
from blacksheep import Application, get, html, pretty_json
from blacksheep.server.authentication.oidc import OpenIDSettings, use_openid_connect
from guardpost.authentication import Identity

app = Application()


# basic Auth0 integration that handles only an id_token
use_openid_connect(
    app,
    OpenIDSettings(
        authority="<YOUR_AUTHORITY>",
        client_id="<CLIENT_ID>",
        callback_path="<CALLBACK_PATH>",
    ),
)


@get("/")
async def home(user: Identity):
    if user.is_authenticated():
        response = pretty_json(user.claims)

        return response

    return html("<a href='/sign-in'>Sign in</a><br/>")
```

Where:

| Parameter      | Description                                                                                                                                                                                            |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| YOUR_AUTHORITY | The URL to your account, like `https://neoteroi.eu.auth0.com`                                                                                                                                          |
| CLIENT_ID      | Your app registration ID                                                                                                                                                                               |
| CALLBACK_PATH  | The path that is enabled for `reply_uri` in your app settings, for example if you enabled for localhost: `http://localhost:5000/authorization-callback`, the value should be `/authorization-callback` |

For more information and examples, refer to the dedicated page about
[OpenID Connect authentication](openid-connect.md).

## JWT Bearer

BlackSheep implements built-in support for JWT Bearer authentication, and
validation of JWTs:

* Issued by identity providers implementing OpenID Connect (OIDC) discovery
  (such as Auth0, Microsoft Entra ID).
* And more in general, JWTs signed using asymmetric encryption and verified
  using public RSA keys.

The following example shows how to configure JWT Bearer authentication for an
application registered in `Microsoft Entra ID`, and also how to configure
authorization to restrict access to certain methods, only for users who are
successfully authenticated:

```python
from guardpost import Policy, User
from guardpost.common import AuthenticatedRequirement

from blacksheep import Application, get, json
from blacksheep.server.authentication.jwt import JWTBearerAuthentication
from blacksheep.server.authorization import auth

app = Application()

app.use_authentication().add(
    JWTBearerAuthentication(
        authority="https://login.microsoftonline.com/<YOUR_TENANT_NAME>.onmicrosoft.com",
        valid_audiences=["<YOUR_APP_CLIENT_ID>"],
        valid_issuers=["https://login.microsoftonline.com/<YOUR_TENANT_ID>/v2.0"],
    )
)

# configure authorization, to restrict access to methods using @auth decorator
authorization = app.use_authorization()

authorization += Policy("example_name", AuthenticatedRequirement())


@get("/")
def home():
    return "Hello, World"


@auth("example_name")
@get("/api/message")
def example():
    return "This is only for authenticated users"


@get("/open/")
async def open(user: User | None):
    if user is None:
        return json({"anonymous": True})
    else:
        return json(user.claims)

```

The built-in handler for JWT Bearer authentication does not currently support
JWTs signed with symmetric keys. Support for symmetric keys might be added in
the future.

/// admonition | 💡

It is possible to configure several `JWTBearerAuthentication` handlers,
for applications that need to support more than one identity provider. For
example, for applications that need to support sign-in through Auth0, Azure
Active Directory, Azure Active Directory B2C.

///

## Writing a custom authentication handler

The example below shows how to configure a custom authentication handler that
obtains the user's identity for each web request.

```python
from blacksheep import Application, Request, auth, get, json
from guardpost import AuthenticationHandler, Identity, User


app = Application(show_error_details=True)


class ExampleAuthHandler(AuthenticationHandler):
    def __init__(self):
        pass

    async def authenticate(self, context: Request) -> Identity | None:
        # TODO: apply the desired logic to obtain a user's identity from
        # information in the web request, for example reading a piece of
        # information from a header (or cookie).
        header_value = context.get_first_header(b"Authorization")

        if header_value:
            # implement your logic to obtain the user
            # in this example, an identity is hard-coded just to illustrate
            # testing in the next paragraph
            context.identity = Identity({"name": "Jan Kowalski"}, "MOCK")
        else:
            # if the request cannot be authenticated, set the context.identity
            # to None - do not throw exception because the app might support
            # different ways to authenticate users
            context.identity = None
        return context.identity


app.use_authentication().add(ExampleAuthHandler())


@get("/")
def home():
    return "Hello, World"


@auth("example_name")
@get("/api/message")
def example():
    return "This is only for authenticated users"


@get("/open/")
async def open(user: User | None):
    if user is None:
        return json({"anonymous": True})
    else:
        return json(user.claims)

```

It is possible to configure several authentication handlers to implement
different ways to identify users. To distinguish how the user was
authenticated, use the second parameter of the Identity constructor:

```python
identity = Identity({"name": "Jan Kowalski"}, "AUTHENTICATION_MODE")
```

The authentication context is the `Request` instance created to handle the
incoming web request. Authentication handlers must set the `identity` property on
the request to enable the automatic injection of `user` via dependency injection.

### Testing the example

To test the example above, start a web server as explained in the [getting
started guide](getting-started.md), then navigate to its root. A web request to
the root of the application without an `Authorization` header will produce a
response with the following body:

```json
{"anonymous":true}
```

While a web request with an `Authorization` header will produce a response with
the following body:

```json
{"name":"Jan Kowalski"}
```

For example, to generate web requests using `curl`:

```bash
curl  http://127.0.0.1:44555/open
```

Gets the output: `{"anonymous":true}`.

```bash
curl -H "Authorization: foo" http://127.0.0.1:44555/open
```

Gets the output: `{"name":"Jan Kowalski"}`.

_The application has been started on port 44555 (e.g. `uvicorn server:app --port=44555`)._

## Reading a user's context

The example below shows how a user's identity can be read from the web request:

=== "Using binders (recommended)"

    ```python
    from guardpost.authentication import Identity


    @get("/")
    async def for_anybody(user: Identity | None):
        ...
    ```

=== "Directly from the request"

    ```python

    @get("/")
    async def for_anybody(request: Request):
        user = request.identity
        # user can be None or an instance of Identity (set in the authentication
        # handler)
    ```

## Dependency Injection in authentication handlers

Dependency Injection is supported in authentication handlers. To use it:

1. Configure `AuthenticationHandler` objects as types (not instances)
   associated to the `AuthenticationStrategy` object.
2. Register dependencies in the DI container, and in the handler classes
   according to the solution you are using for dependency injection.

The code below illustrates and example using the built-in solution for DI.

```python {linenums="1" hl_lines="7-8 11-13 23-26 28-30"}
from blacksheep import Application, Request, json
from guardpost import AuthenticationHandler, Identity

app = Application()


class ExampleDependency:
    pass


class MyAuthenticationHandler(AuthenticationHandler):
    def __init__(self, dependency: ExampleDependency) -> None:
        self.dependency = dependency

    def authenticate(self, context: Request) -> Identity | None:
        # TODO: implement your own authentication logic
        assert isinstance(self.dependency, ExampleDependency)
        return Identity({"id": "example", "sub": "001"}, self.scheme)


auth = app.use_authentication()  # AuthenticationStrategy

# The authentication handler will be instantiated by `app.services`,
# which can be any object implementing the ContainerProtocol
auth.add(MyAuthenticationHandler)

# We need to register the types in the DI container!
app.services.register(MyAuthenticationHandler)
app.services.register(ExampleDependency)


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

## Next

While authentication focuses on *identifying* users, authorization determines
whether a user *is permitted* to perform the requested action. The next page
describes the built-in [authorization strategy](authorization.md) in
BlackSheep.

<!--

/// admonition | Additional dependencies.
    type: warning

Using JWT Bearer and OpenID integrations requires additional dependencies.
Install them by running: `pip install blacksheep[full]`.

///

## Underlying library

The authentication and authorization logic for BlackSheep is packaged and
published in a dedicated library:
[`guardpost`](https://github.com/neoteroi/guardpost) ([in
pypi](https://pypi.org/project/guardpost/)).

-->
