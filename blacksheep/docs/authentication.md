# Authentication in BlackSheep

The term 'authentication strategy' in the context of a web application refers
to the process of identifying the user accessing the application. BlackSheep
provides a built-in authentication strategy for request handlers. This page
covers:

- [X] How to use the built-in authentication strategy.
- [X] How to configure a custom authentication handler.
- [X] How to use the built-in support for **API Key** authentication.
- [X] How to use the built-in support for **Basic** authentication.
- [X] How to use the built-in support for **JWT Bearer** authentication.
- [X] How to use the built-in support for **Cookie** authentication.
- [X] How to read the user's context in request handlers.
- [X] How authentication can be documented in **OpenAPI Documentation**.

/// admonition | Additional dependencies.
    type: warning

Using JWT Bearer and OpenID integrations requires additional dependencies.
Install them by running: `pip install blacksheep[full]`.

///

## How to use built-in authentication

Common strategies for identifying users in web applications include:

- Reading a signed token from a cookie.
- Handling API Keys sent in custom headers.
- Handling basic credentials sent in `Authorization: Basic ***` headers.
- Handling JSON Web Tokens (JWTs) signed and including payloads with information
  about the user, transmitted using `Authorization: Bearer ***` request headers.

The following sections describe how to enable authentication using built-in
classes, and how to define custom authentication handlers.

## API Key authentication

Since version `2.4.2`, BlackSheep provides built-in support for API Key
authentication with flexible configuration options. API Keys can be read from
request headers, query parameters, or cookies, and each key can be associated
with specific roles and claims.

### Enabling API Key authentication

The following example illustrates how API Key authentication can be enabled:

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

You can configure multiple API Keys with different roles and claims:

```python
from blacksheep import Application, get
from blacksheep.server.authentication.apikey import APIKey, APIKeyAuthentication
from blacksheep.server.authorization import auth
from essentials.secrets import Secret


app = Application()

app.use_authentication().add(
    APIKeyAuthentication(
        # Admin API key with full access
        APIKey(
            secret=Secret("$ADMIN_API_KEY"),
            roles=["admin", "user"],
            claims={"department": "IT"}
        ),
        # Regular user API key
        APIKey(
            secret=Secret("$USER_API_KEY"),
            roles=["user"],
            claims={"department": "sales"}
        ),
        # Read-only API key
        APIKey(
            secret=Secret("$READONLY_API_KEY"),
            roles=["readonly"],
            claims={}
        ),
        param_name="X-API-Key",
    )
)

app.use_authorization()


@auth()
@get("/")
async def get_user_info(request):
    return {
        "roles": request.user.roles,
        "claims": request.user.claims
    }
```

### API Key locations

API Keys can be retrieved from different locations in the request:

=== "Header (default)"

    ```python
    app.use_authentication().add(
        APIKeyAuthentication(
            APIKey(secret=Secret("your-secret-key")),
            param_name="X-API-Key",
            location="header"  # Default location
        )
    )
    ```

    Test with: `curl -H "X-API-Key: your-secret-key" http://localhost:8000/`

=== "Query"

    ```python
    app.use_authentication().add(
        APIKeyAuthentication(
            APIKey(secret=Secret("your-secret-key")),
            param_name="api_key",
            location="query"
        )
    )
    ```

    Test with: `curl http://localhost:8000/?api_key=your-secret-key`

=== "Cookie"

    ```python
    app.use_authentication().add(
        APIKeyAuthentication(
            APIKey(secret=Secret("your-secret-key")),
            param_name="api_key",
            location="cookie"
        )
    )
    ```

    Test with: `curl -b "api_key=your-secret-key" http://localhost:8000/`

### Dynamic API Key provider

For scenarios where API Keys need to be retrieved dynamically (e.g., from a database),
implement the `APIKeysProvider` abstract class:

```python
from typing import List
from blacksheep import Application, get
from blacksheep.server.authentication.apikey import (
    APIKey,
    APIKeyAuthentication,
    APIKeysProvider
)
from blacksheep.server.authorization import auth
from essentials.secrets import Secret


class DatabaseAPIKeysProvider(APIKeysProvider):
    """
    Example provider that retrieves API keys from a database.
    """

    def __init__(self, db_connection):
        self.db = db_connection

    async def get_keys(self) -> List[APIKey]:
        """
        Fetch API keys from database with associated roles and claims.
        """
        # Example database query (adapt to your database)
        keys_data = await self.db.fetch_all("""
            SELECT secret, roles, department, access_level
            FROM api_keys
            WHERE is_active = true
        """)

        api_keys = []
        for row in keys_data:
            api_keys.append(APIKey(
                secret=Secret(row["secret"], direct_value=True),
                roles=row["roles"].split(",") if row["roles"] else [],
                claims={
                    "department": row["department"],
                    "access_level": row["access_level"]
                }
            ))

        return api_keys


# Usage with dynamic provider
app = Application()

# Assume you have a database connection
# db_connection = get_database_connection()

app.use_authentication().add(
    APIKeyAuthentication(
        param_name="X-API-Key",
        keys_provider=DatabaseAPIKeysProvider(db_connection)
    )
)

app.use_authorization()


@auth()
@get("/")
async def protected_endpoint(request):
    return {
        "message": "Access granted",
        "user_department": request.user.claims.get("department"),
        "access_level": request.user.claims.get("access_level")
    }
```

**Note:** dependency injection is also supported, configuring the
authentication handler as a _type_ to be instantiated rather than an instance.

### Advanced API Key configuration

You can customize the authentication scheme and add descriptions:

```python
app.use_authentication().add(
    APIKeyAuthentication(
        APIKey(
            secret=Secret("$API_SECRET"),
            roles=["service"],
            claims={"client_type": "external_service"}
        ),
        param_name="X-Service-Key",
        scheme="ServiceKey",  # Custom scheme name
        location="header",
        description="External service authentication using API keys"
    )
)
```

## Basic authentication

Since version `2.4.2`, BlackSheep provides built-in support for HTTP Basic
Authentication, which allows clients to authenticate using a username and password
combination. Basic authentication credentials can be configured statically or retrieved
dynamically from external sources.

### Enabling Basic authentication

The following example shows how to configure Basic authentication with static
credentials:

```python
from blacksheep import Application, get
from blacksheep.server.authentication.basic import BasicAuthentication, BasicCredentials
from blacksheep.server.authorization import auth
from essentials.secrets import Secret


app = Application()

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

You can configure multiple users with different roles and claims:

```python
from blacksheep import Application, get
from blacksheep.server.authentication.basic import BasicAuthentication, BasicCredentials
from blacksheep.server.authorization import auth
from essentials.secrets import Secret


app = Application()

app.use_authentication().add(
    BasicAuthentication(
        # Admin user with full access
        BasicCredentials(
            username="admin",
            password=Secret("$ADMIN_PASSWORD"),
            roles=["admin", "user"],
            claims={"department": "IT", "level": "admin"}
        ),
        # Regular user
        BasicCredentials(
            username="john_doe",
            password=Secret("$JOHN_PASSWORD"),
            roles=["user"],
            claims={"department": "sales", "level": "user"}
        ),
        # Read-only user
        BasicCredentials(
            username="guest",
            password=Secret("$GUEST_PASSWORD"),
            roles=["readonly"],
            claims={"department": "public", "level": "guest"}
        )
    )
)

app.use_authorization()


@auth()
@get("/")
async def get_user_info(request):
    return {
        "username": request.user.claims.get("sub"),
        "roles": request.user.roles,
        "claims": request.user.claims
    }
```

Test with curl:
```bash
# Admin user
curl -u "admin:admin_password_here" http://localhost:8000/

# Regular user
curl -u "john_doe:john_password_here" http://localhost:8000/

# Guest user
curl -u "guest:guest_password_here" http://localhost:8000/
```

### Dynamic credentials provider

For scenarios where credentials need to be retrieved dynamically (e.g., from a database
or LDAP), implement the `BasicCredentialsProvider` abstract class:

```python
from typing import List
from blacksheep import Application, get
from blacksheep.server.authentication.basic import (
    BasicAuthentication,
    BasicCredentials,
    BasicCredentialsProvider
)
from blacksheep.server.authorization import auth
from essentials.secrets import Secret


class DatabaseCredentialsProvider(BasicCredentialsProvider):
    """
    Example provider that retrieves credentials from a database.
    """

    def __init__(self, db_connection):
        self.db = db_connection

    async def get_credentials(self) -> List[BasicCredentials]:
        """
        Fetch credentials from database with associated roles and claims.
        """
        # Example database query (adapt to your database)
        users_data = await self.db.fetch_all("""
            SELECT username, password_hash, roles, department, access_level
            FROM users
            WHERE is_active = true
        """)

        credentials = []
        for row in users_data:
            # TODO: return a custom subclass of BasicCredentials that overrides the
            # `match` method to handle the password_hash (as the client will send a
            # password in clear text!)
            credentials.append(BasicCredentials(
                username=row["username"],
                password=Secret(row["password_hash"], direct_value=True),
                roles=row["roles"].split(",") if row["roles"] else [],
                claims={
                    "department": row["department"],
                    "access_level": row["access_level"]
                }
            ))

        return credentials


# Usage with dynamic provider
app = Application()

# Assume you have a database connection
# db_connection = get_database_connection()

app.use_authentication().add(
    BasicAuthentication(
        credentials_provider=DatabaseCredentialsProvider(db_connection)
    )
)

app.use_authorization()


@auth()
@get("/")
async def protected_endpoint(request):
    return {
        "message": "Access granted",
        "username": request.user.claims.get("sub"),
        "department": request.user.claims.get("department"),
        "access_level": request.user.claims.get("access_level")
    }
```

**Note:** dependency injection is also supported, configuring the authentication handler as a _type_ to be instantiated rather than an instance.

### Generating authorization headers

The `BasicCredentials` class provides a utility method to generate the Authorization header value:

```python
from blacksheep.server.authentication.basic import BasicCredentials
from essentials.secrets import Secret

# Create credentials
admin_credentials = BasicCredentials(
    username="admin",
    password=Secret("secret_password", direct_value=True)
)

# Generate the Authorization header value
header_value = admin_credentials.to_header_value()
print(header_value)  # Output: Basic YWRtaW46c2VjcmV0X3Bhc3N3b3Jk

# Use in HTTP client
import httpx

response = httpx.get(
    "http://localhost:8000/protected",
    headers={"Authorization": header_value}
)
```

### Advanced configuration

You can customize the authentication scheme:

```python
app.use_authentication().add(
    BasicAuthentication(
        BasicCredentials(
            username="service",
            password=Secret("$SERVICE_PASSWORD"),
            roles=["service"],
            claims={"client_type": "internal_service"}
        ),
        scheme="InternalBasic",  # Custom scheme name
        description="Internal service authentication using Basic auth"
    )
)
```

/// admonition | Security recommendations
    type: warning

When implementing Basic authentication:

- **Always use HTTPS** in production to protect credentials in transit.
- Use strong, unique passwords and consider password policies.
- If you store password in a database, store hashes with salt, not plain text passwords.
  If you work with hashes and salts, define a subclass of `BasicCredentials` that
  overrides the `match` method to handle hashes according to your preference.

///

## Cookie

BlackSheep implements a built-in class for Cookie authentication. This class can be
used to authenticate users based on a cookie, and it is used internally by default with
the OIDC integration (after a user successfully signs-in with an external identity
provider, the user context is stored in a cookie by default).

Cookie authentication automatically handles setting, validating, and unsetting cookies
with signed and encrypted user data using `itsdangerous.Serializer`.

### Basic Cookie authentication setup

The following example shows how to use the built-in `CookieAuthentication` class:

```python
import secrets
from datetime import datetime, timedelta, UTC

from blacksheep import Application, get, json, post
from blacksheep.server.authentication.cookie import CookieAuthentication

app = Application()

# Secure cookie configuration
cookie_auth = CookieAuthentication(
    cookie_name="secure_session",
    secret_keys=[
        secrets.token_urlsafe(32),
        secrets.token_urlsafe(32),
    ],
)
app.use_authentication().add(cookie_auth)


@get("/")
async def home(request) -> dict:
    return request.user.claims


@post("/login")
async def secure_login(request):
    # TODO: Validate credentials

    response = json({"success": True})

    # Set cookie with expiration
    user_data = {
        "sub": "user123",
        "name": "John Doe",
        "exp": int((datetime.now(UTC) + timedelta(hours=24)).timestamp()),
    }

    cookie_auth.set_cookie(
        user_data,
        response,
        secure=True,  # Always use secure=True in production with HTTPS
    )
    return response


@get("/logout")
async def logout(request):
    """Example logout endpoint that removes authentication cookie"""
    response = json({"message": "Logged out"})

    # Remove the authentication cookie
    cookie_auth.unset_cookie(response)
    return response
```

**Summary:**
- `set_cookie` is used to securely set an authentication cookie containing user claims and expiration, typically after a successful login.
- `unset_cookie` removes the authentication cookie, logging the user out.
- `request.user.claims` allows you to access the authenticated user's claims in request handlers, such as user ID, name, or roles.

/// admonition | Security recommendations
    type: warning

When implementing Cookie authentication:

- **Do not** hard-code secrets in source code. The examples above are just **examples**.
- **Use strong secret keys**: Generate cryptographically secure random keys,
  for example using `secrets.choice`.
- **Enable secure flag**: Always set `secure=True` when using HTTPS in production.
- **Key rotation**: Use multiple secret keys to support key rotation without breaking
  existing sessions.
- **Set expiration**: Include `exp` claim in cookie data to control session lifetime.
- **Use HTTPS**: Never transmit authentication cookies over unencrypted connections.

///

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

### With Asymmetric Encryption

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

The built-in handler for JWT Bearer authentication also supports symmetric encryption,
but only since version `2.4.2`.

/// admonition | 💡

It is possible to configure several `JWTBearerAuthentication` handlers,
for applications that need to support more than one identity provider. For
example, for applications that need to support sign-in through Auth0, Azure
Active Directory, Azure Active Directory B2C.

///

### With Symmetric Encryption

Since version `2.4.2`, BlackSheep supports JWT Bearer authentication with symmetric
encryption using shared secret keys. This is useful for scenarios where you control both
the token issuer and validator, such as internal services or microservices
architectures.

The following example shows how to configure JWT Bearer authentication with a symmetric
secret key:

```python
from blacksheep import Application, get, json
from blacksheep.server.authentication.jwt import JWTBearerAuthentication
from blacksheep.server.authorization import auth
from essentials.secrets import Secret

app = Application()

app.use_authentication().add(
    JWTBearerAuthentication(
        secret_key=Secret("$JWT_SECRET"),  # ⟵ obtained from JWT_SECRET env var
        valid_audiences=["my-service"],
        valid_issuers=["my-issuer"],
        algorithms=["HS256"],  # ⟵ symmetric algorithms: HS256, HS384, HS512
        scheme="JWT Symmetric"
    )
)

app.use_authorization()


@auth()
@get("/protected")
async def protected_endpoint(request):
    return {
        "message": "Access granted",
        "user": request.user.claims.get("sub"),
        "roles": request.user.claims.get("roles", [])
    }
```

#### Supported symmetric algorithms

When using symmetric encryption, the following algorithms are supported:

- `HS256` (HMAC using SHA-256) - **recommended**
- `HS384` (HMAC using SHA-384)
- `HS512` (HMAC using SHA-512)

#### Creating symmetric JWTs

You can create JWTs for testing using Python's `PyJWT` library:

```python
import jwt
from datetime import datetime, timedelta

# Your shared secret (same as in the authentication config)
secret = "your-secret-key-here"

# Create a JWT payload
payload = {
    "sub": "user123",
    "aud": "my-service",
    "iss": "my-issuer",
    "exp": datetime.utcnow() + timedelta(hours=1),
    "iat": datetime.utcnow(),
    "roles": ["user", "admin"]
}

# Generate the token
token = jwt.encode(payload, secret, algorithm="HS256")
print(f"Token: {token}")

# Test with curl
# curl -H "Authorization: Bearer {token}" http://localhost:8000/protected
```

#### Multiple JWT configurations

You can configure both symmetric and asymmetric JWT authentication handlers in the same
application to support different token types:

```python
from blacksheep import Application
from blacksheep.server.authentication.jwt import JWTBearerAuthentication
from essentials.secrets import Secret

app = Application()

# Symmetric JWT for internal services
app.use_authentication().add(
    JWTBearerAuthentication(
        secret_key=Secret("$INTERNAL_JWT_SECRET"),
        valid_audiences=["internal-api"],
        valid_issuers=["internal-issuer"],
        algorithms=["HS256"],
        scheme="JWT Internal"
    )
)

# Asymmetric JWT for external identity providers
app.use_authentication().add(
    JWTBearerAuthentication(
        authority="https://login.microsoftonline.com/tenant.onmicrosoft.com",
        valid_audiences=["external-client-id"],
        valid_issuers=["https://login.microsoftonline.com/tenant-id/v2.0"],
        algorithms=["RS256"],
        scheme="JWT External"
    )
)
```

/// admonition | Symmetric vs Asymmetric
    type: info

**Symmetric encryption** (shared secret):

- ✅ Faster validation (no key fetching required)
- ✅ Simpler setup for internal services
- ❌ Same key used for signing and validation
- ❌ Key distribution challenges in distributed systems

**Asymmetric encryption** (public/private keys):

- ✅ Better security model (separate keys for signing/validation)
- ✅ Better for third-party integrations
- ❌ Slower validation (key fetching and cryptographic operations)
- ❌ More complex setup

Choose symmetric encryption for internal services where you control both token creation
and validation. Use asymmetric encryption when integrating with external identity
providers or when you need to distribute validation capabilities without sharing signing
keys.

///

/// admonition | Security considerations
    type: warning

When using symmetric JWT authentication:

- **Use strong secret keys**: Generate cryptographically secure random keys of at least
  256 bits for HS256.
- **Protect your secrets**: Store secret keys securely and never commit them to version
  control.
- **Key rotation**: Implement a strategy for rotating secret keys periodically.
- **Secure transmission**: Always use HTTPS in production to protect tokens in transit.
- **Token expiration**: Set appropriate expiration times (`exp` claim) for your tokens.

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

As documented in [_Container Protocol_](./dependency-injection.md#the-container-protocol),
BlackSheep supports the use of other DI containers as replacements for the
built-in library used for dependency injection.

///


### Error handling and security considerations

When using authentication and authorization, consider these security practices:

```python
from blacksheep import Application, get, json
from blacksheep.server.authentication...
from blacksheep.exceptions import Unauthorized
from essentials.secrets import Secret


app = Application()

app.use_authentication().add(
    ...
)

app.use_authorization()


@get("/public")
async def public_endpoint():
    """Public endpoint that doesn't require authentication."""
    return {"message": "This is public"}


@auth()
@get("/protected")
async def protected_endpoint(request):
    """Protected endpoint that requires an authenticated user."""
    return {
        "message": "Access granted",
        "roles": request.user.roles
    }


@get("/optional-auth")
async def optional_auth_endpoint(request):
    """Endpoint with optional authentication."""
    if request.user and request.user.is_authenticated():
        return {
            "message": "Authenticated user",
            "roles": request.user.roles
        }
    else:
        return {"message": "Anonymous user"}
```

## Underlying library

The authentication and authorization logic for BlackSheep is packaged and
published in a dedicated library:
[`guardpost`](https://github.com/neoteroi/guardpost) ([in
pypi](https://pypi.org/project/guardpost/)).

## Next

While authentication focuses on *identifying* users, authorization determines
whether a user *is permitted* to perform the requested action. The next page
describes the built-in [authorization strategy](authorization.md) in
BlackSheep.

/// note | Documenting authentication.

For information on how to document authentication schemes in OpenAPI
Specification files, refer to [_Documenting authentication_](./openapi.md#documenting-authentication).

///
