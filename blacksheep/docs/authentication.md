# Authentication in BlackSheep
The words "authentication strategy" in the context of a web application refer
to the ability to identify the user who is using the application. BlackSheep
implements a built-in authentication strategy for request handlers. This page
describes:

- [X] How to use the built-in authentication strategy.
- [X] How to configure a custom authentication handler.
- [X] How to use the built-in support for JWT Bearer authentication.
- [X] How to read the user's context in request handlers.

!!! warning
    Using JWT Bearer and OpenID integrations requires more dependencies: use
    `pip install blacksheep[full]` to use these features

## Underlying library
The authentication and authorization logic implemented for BlackSheep was
packed and published into a dedicated library:
[`guardpost`](https://github.com/neoteroi/guardpost) ([in
pypi](https://pypi.org/project/guardpost/)).

## How to use built-in authentication

Examples of common strategies to identify users in web applications include:

- reading an `Authorization: Bearer xxx` request header containing a [JWT](https://jwt.io/introduction/)
  with claims that identify the user
- reading a signed token from a cookie

The next paragraphs explain first how to use the built-in support for JWT
Bearer tokens, and how to write a custom authentication handler.

!!! info
    The word "user" is usually used only to refer to human users, while
    the word "service" is used to describe non-human clients. In Java and .NET, a
    common word to describe a generic identity is "principal".

## OIDC

BlackSheep implements built-in support for OpenID Connect authentication,
meaning that it can be easily integrated with identity provider services such
as:

- [Auth0](https://auth0.com)
- [Entra ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id)
- [Azure Active Directory B2C](https://docs.microsoft.com/en-us/azure/active-directory-b2c/overview)
- [Okta](https://www.okta.com)

!!! tip "Examples in GitHub"
    The [Neoteroi/BlackSheep-Examples/](https://github.com/Neoteroi/BlackSheep-Examples/)
    repository in GitHub contains examples of JWT Bearer authentication and
    OpenID Connect integrations.

A basic example integration with any of the identity providers above, having
implicit flow enabled for `id_token` (meaning that the code doesn't need to
handle any secret), looks like the following:

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
[OpenID Connect authentication](../openid-connect).

## JWT Bearer

BlackSheep implements built-in support for JWT Bearer authentication, and
validation of JWTs:

* issued by identity providers implementing OpenID Connect (OIDC) discovery
  (such as Auth0, Azure Active Directory)
* and more in general, JWTs signed using asymmetric encryption and verified
  using public RSA keys

The following example shows how to configure JWT Bearer authentication for an
application registered in `Azure Active Directory`, and also how to configure
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

The built-in handler for JWT Bearer authentication does not support JWTs signed
with symmetric keys. Support for symmetric keys might be added in the future,
inside **[guardpost](https://github.com/Neoteroi/guardpost)** library.

!!! info
    💡 It is possible to configure several JWTBearerAuthentication handlers,
    for applications that need to support more than one identity provider. For
    example, for applications that need to support sign-in through Auth0, Azure
    Active Directory, Azure Active Directory B2C.

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
different ways to identify users. To differentiate the way the user has been
authenticated, use the second parameter of `Identity`'s constructor:

```python
identity = Identity({"name": "Jan Kowalski"}, "AUTHENTICATION_MODE")
```

The authentication context is the instance of `Request` created to handle the
incoming web request. Authentication handlers must set the `identity` property
on the request, to enable automatic injection of `user` by dependency injection.

### Testing the example

To test the example above, start a web server as explained in the [getting
started guide](../getting-started), then navigate to its root. A web request to
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

## Next
While authentication deals with identifying users, authorization deals with
determining whether the user is authorized to do the action of the web request.
The next page describes the built-in [authorization strategy](../authorization)
in BlackSheep.
