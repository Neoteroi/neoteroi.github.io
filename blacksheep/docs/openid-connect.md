# OpenID Connect

BlackSheep implements built-in support for OpenID Connect authentication,
meaning that it can be easily integrated with identity provider services such
as:

* [Auth0](https://auth0.com)
* [Entra ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id)
* [Azure Active Directory B2C](https://docs.microsoft.com/en-us/azure/active-directory-b2c/overview)
* [Okta](https://www.okta.com)

This page documents:

- [X] How to use OpenID Connect integration to provide sign-in and sign-up features,
  and to identify users who use the application
- [X] How to use OpenID Connect integration to obtain `access_token`s to use APIs
  (in addition, or instead of `id_token`s)
- [X] How tokens are protected and how to configure applications to support
  multiple instances and regions

!!! warning
    Using JWT Bearer and OpenID integrations requires more dependencies: use
    `pip install blacksheep[full]` to use these features

## Basic example

A basic example with any of the identity providers listed above, having
implicit flow enabled for `id_token`, looks like the following:

```python
from blacksheep import Application, html, pretty_json
from blacksheep.server.authentication.oidc import OpenIDSettings, use_openid_connect
from guardpost.authentication import Identity

app = Application()


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

When the application is configured with `use_openid_connect`, request handlers
are automatically configured to handle users' sign-in, the redirect after a
user signs-in, and signs-out. After a user signs-in successfully, a signed and
encrypted cookie containing the claims of the `id_token` is set automatically
for the client, having an expiration time matching the expiration time of the
`id_token` itself. User's identity is automatically restored at each web
request by an authentication middleware, and can be read as in the provided
examples:

```python
@get("/")
async def home(user: Identity):
    if user.is_authenticated():
        ...
```

### use_openid_connect

| Parameter          | Type, default                                                     | Description                                                                                                                                                                                                                       |
| ------------------ | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| app                | Application                                                       | Instance of BlackSheep application.                                                                                                                                                                                               |
| settings           | OpenIDSettings                                                    | Instance of OpenIDSettings.                                                                                                                                                                                                       |
| auth_handler       | Optional[OpenIDTokensHandler] = None (CookiesOpenIDTokensHandler) | Instance of OpenIDTokensHandler that can handle tokens for requests and responses for the OpenID Connect flow. This class is responsible for communicating tokens to clients, and restoring tokens context for following requests. |
| parameters_builder | Optional[ParametersBuilder] = None                                | Optional instance of `ParametersBuilder`, used to handle parameters configured in redirects and requests to the authorization server.                                                                                             |
| is_default         | bool = True                                                       | If default, clients are automatically redirected to the `sign-in` page when a non-authenticated user tries to access in `GET` a web page that requires authentication.                                                            |

### OpenIDSettings

The `OpenIDSettings` class has the following properties:

| Parameter                 | Type, default                   | Description                                                                                                                                                                           |
| ------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| client_id                 | str                             | ID of the application in the identity server.                                                                                                                                         |
| authority                 | Optional[str] = None            | If specified, URL of the authorization server.                                                                                                                                        |
| audience                  | Optional[str] = None            | If specified, the `audience` for requests using scopes to an API ([ref.](https://auth0.com/docs/configure/apis/scopes/sample-use-cases-scopes-and-claims#request-custom-api-access)). |
| client_secret             | Optional[str] = None            | For requests that use `Authorization Code Grant` flow, the secret of the client application in the identity server.                                                                   |
| discovery_endpoint        | Optional[str] = None            | If specified, the exact URL to the discovery point (useful with Okta when using custom scopes for an authorization server).                                                           |
| entry_path                | str = "/sign-in"                | The local entry path for sign-in (this redirects to the sign-in page of the identity server).                                                                                         |
| logout_path               | str = "/sign-out"               | The local path to the sign-out endpoint (this removes authentication cookie).                                                                                                         |
| post_logout_redirect_path | str = "/"                       | The local path to which a user is redirected after signing-out.                                                                                                                       |
| callback_path             | str = "/authorization-callback" | The local path to handle the redirect after a user signs-in (the reply_url in the identity server must be configured accordingly).                                                    |
| refresh_token_path        | str = "/refresh-token"          | The local path used to handle refresh tokens to obtain new tokens.                                                                                                                    |
| scope                     | str = "openid profile email"    | The scope of the request, by default an `id_token` is obtained with email and profile.                                                                                                |
| response_type             | str = "code"                    | Type of OAuth response.                                                                                                                                                               |
| redirect_uri              | Optional[str] = None            | If specified, the redirect URL that must match the one configured for the application. If not provided, a redirect_url is obtained automatically (see note 🗡️).                       |
| scheme_name               | str = "OpenIDConnect"           | The name of the authentication scheme, affecting the name of authentication cookies (see note 🍒).                                                                                    |
| error_redirect_path       | Optional[str] = None            | If specified, the local path to which a user is redirected in case of error.                                                                                                          |
| end_session_endpoint      | Optional[str] = None            | If specified, the local path to which the user can log out.                                                                                                                           |

Notes:

* 🗡️ obtaining a redirect_url automatically can require handling of forward
  headers, when an application is deployed behind a proxy. See
  [remotes for more information](../remotes).
* 🍒 this should be changed when configuring more than one OIDC identity
  provider.

!!! info
    `access_token`s issued for APIs can be validated using
    [JWT Bearer authentication](../authentication/#jwt-bearer)

## Examples using custom scopes

An integration with an `Auth0` application that uses custom scopes, where the
application obtains both an `id_token` and an `access_token` for an API,
looks like the following:

```python
"""
This example shows how to configure an OpenID Connect integration with Auth0, obtaining
an id_token, an access_token, and a refresh_token. The id_token is exchanged with the
client using a response cookie (also used to authenticate users
for following requests), while the access token and the refresh token are not stored
and can only be accessed using optional events.
"""
import uvicorn
from blacksheep.server.application import Application
from blacksheep.server.authentication.oidc import OpenIDSettings, use_openid_connect
from dotenv import load_dotenv

from common.routes import register_routes
from common.secrets import Secrets

load_dotenv()
secrets = Secrets.from_env()
app = Application(show_error_details=True)


# Auth0 with a custom scope
use_openid_connect(
    app,
    OpenIDSettings(
        authority="https://neoteroi.eu.auth0.com",
        audience="http://localhost:5000/api/todos",
        client_id="OOGPl4dgG7qKsm2IOWq72QhXV4wsLhbQ",
        client_secret=secrets.auth0_client_secret,
        callback_path="/signin-oidc",
        scope="openid profile read:todos",
        error_redirect_path="/sign-in-error",
    ),
)

register_routes(app)


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5000, log_level="debug")

```

An integration with `Entra ID`:

```python
handler = use_openid_connect(
    app,
    OpenIDSettings(
        authority="https://login.microsoftonline.com/b62b317a-19c2-40c0-8650-2d9672324ac4/v2.0/",
        client_id="499adb65-5e26-459e-bc35-b3e1b5f71a9d",
        client_secret=secrets.aad_client_secret,
        scope="openid profile offline_access email "
        "api://65d21481-4f1a-4731-9508-ad965cb4d59f/example",
    ),
)
```

An integration with `Okta`, using the `default` authorization server:

```python
use_openid_connect(
    app,
    OpenIDSettings(
        discovery_endpoint="https://dev-34685660.okta.com/oauth2/default/.well-known/oauth-authorization-server",
        client_id="0oa2gy88qiVyuOClI5d7",
        client_secret=secrets.okta_client_secret,
        callback_path="/authorization-code/callback",
        scope="openid read:todos",
    ),
)
```

## Events

The API exposes the following events:

```python
from blacksheep.server.authentication.oidc import (
    OpenIDSettings,
    TokenResponse,
    use_openid_connect
)


oidc = use_openid_connect(...)


@oidc.events.on_id_token_validated
async def id_token_callback(context, id_token_claims):
    """
    This callback is called after an id_token is received, successfully
    verified using public RSA keys from the identity provider, and parsed

    Using this event handler is possible to modify the claims obtained from the
    id_token before they are set in the authentication cookie. For example to
    remove certain claims, or add other information.
    """


@oidc.events.on_tokens_received
async def on_tokens_received(context, token_response: TokenResponse):
    """
    This callback is called after a successful web request to the token
    endpoint to exchange a code with an access_token, and eventually
    refresh_token, and id_token.
    """


@oidc.events.on_error
async def on_error(context, data: Dict[str, Any]):
    """
    This callback is called when an error is returned by the authorization
    server in the redirect handler.
    Note that this can happen for a common scenario, like the user refusing
    to grant consent on the application.
    """
```

## Storing tokens

By default, `access_token`(s) and `refresh_token`(s) are not stored. To store
them, the `auth_handler.tokens_store` property. The examples repository includes
an example that shows how to use `Redis` to store tokens:
_[Redis example](https://github.com/Neoteroi/BlackSheep-Examples/blob/main/oidc/scopes_redis_aad.py)_

A concrete implementation is
provided in `CookiesTokenStore`, storing tokens in cookies. It is possible to
create custom implementations of the `TokensStore`, to use other mechanisms,
for example, to store tokens in a Redis cache.

When a user is authenticated, and has an `access_token` (and/or a
`refresh_token`), they are accessible through the `Identity`:

```python
@get("/")
async def home(user: Identity):
    if user.is_authenticated():
        print(user.access_token)
        print(user.refresh_token)
        ...
```

To see how to use a `TokensStore`, refer to the examples above that use
the built-in `CookiesTokensStore`.

## Useful references

* [https://auth0.com/docs/security/tokens/access-tokens](https://auth0.com/docs/security/tokens/access-tokens)
* [https://www.oauth.com/oauth2-servers/server-side-apps/possible-errors/](https://www.oauth.com/oauth2-servers/server-side-apps/possible-errors/)
* [https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-implicit-grant-flow](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-implicit-grant-flow)
* [https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc)
* [https://connect2id.com/learn/openid-connect](https://connect2id.com/learn/openid-connect)

## How tokens are protected
Tokens that are stored in cookies are signed and encrypted using `itsdangerous`,
with symmetric encryption. This means that BlackSheep applications need secrets
to protect sensitive data. When keys are not specified, they are generated
automatically in memory, for the best user experience.

!!! danger
    This means that keys are <strong>not persisted</strong> when applications
    restart, and are not consistent when multiple instances of the same
    application are deployed across regions, or within the same server. This is
    acceptable during local development, but should not be the case in
    production environments.

To use consistent keys, configure one or more environment variables like the
following:

* APPSECRET_1="***"
* APPSECRET_2="***"
* APPSECRET_3="***"

Keys can be configured in a host environment, or fetched from a dedicated
service such as `AWS Secrets Manager` or `Azure Key Vault` at application
start-up, and configured as environment settings for the application.
<strong>DO NOT</strong> store secrets that are meant to be used in production
under source control.

For more information, refer to [data protection](../dataprotection/).
