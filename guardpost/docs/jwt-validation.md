# JWT Validation

This page covers GuardPost's built-in JWT validation support, including:

- [X] Installing the JWT extra
- [X] `AsymmetricJWTValidator` for RSA and EC keys
- [X] `SymmetricJWTValidator` for HMAC keys
- [X] `CompositeJWTValidator` — trying multiple validators
- [X] Key sources: `authority`, `keys_url`, `keys_provider`
- [X] The `require_kid` parameter
- [X] Caching behaviour (`cache_time`, `refresh_time`)
- [X] `InvalidAccessToken` and `ExpiredAccessToken` exceptions
- [X] Real-world example: validating tokens from popular identity providers

## Installation

JWT validation is an optional feature. Install the extra to enable it:

```shell
pip install guardpost[jwt]
```

/// admonition | Dependencies
    type: info

The `[jwt]` extra pulls in `PyJWT` and `cryptography`. These are not
installed by default because many applications use GuardPost only for
policy-based authorization without needing JWT parsing.
///

## `AsymmetricJWTValidator`

`AsymmetricJWTValidator` validates JWTs signed with asymmetric keys:

| Algorithm family | Algorithms |
|-----------------|------------|
| RSA | `RS256`, `RS384`, `RS512` |
| EC (Elliptic Curve) | `ES256`, `ES384`, `ES512` |

### RSA keys (RS256)

```python {linenums="1"}
from guardpost.jwts import AsymmetricJWTValidator

validator = AsymmetricJWTValidator(
    valid_issuers=["https://auth.example.com/"],
    valid_audiences=["my-api"],
    algorithms=["RS256"],
    # Fetch JWKS from the OpenID Connect discovery endpoint:
    authority="https://auth.example.com/",
    # cache_time: how long (seconds) to cache keys before re-fetching
    cache_time=10800,   # 3 hours (default)
    # refresh_time: how long after cache_time before proactively refreshing
    refresh_time=120,   # 2 minutes (default)
)

# Validate a token string — raises InvalidAccessToken or ExpiredAccessToken on failure
claims = await validator.validate_jwt(raw_token)
print(claims["sub"])
```

### EC keys (ES256)

```python {linenums="1"}
from guardpost.jwts import AsymmetricJWTValidator

validator = AsymmetricJWTValidator(
    valid_issuers=["https://auth.example.com/"],
    valid_audiences=["my-api"],
    algorithms=["ES256"],
    authority="https://auth.example.com/",
)
```

### Parameters reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `valid_issuers` | `list[str]` | required | Accepted `iss` claim values |
| `valid_audiences` | `list[str]` | required | Accepted `aud` claim values |
| `algorithms` | `list[str]` | `["RS256"]` | Allowed signing algorithms |
| `authority` | `str` | `None` | OpenID Connect issuer URL (auto-discovers JWKS URI) |
| `keys_url` | `str` | `None` | Direct JWKS endpoint URL |
| `keys_provider` | `KeysProvider` | `None` | Custom keys provider instance |
| `require_kid` | `bool` | `True` | Reject tokens that lack a `kid` header |
| `cache_time` | `int` | `10800` | Seconds before cached keys expire |
| `refresh_time` | `int` | `120` | Seconds before expiry to start proactive refresh |

## `SymmetricJWTValidator`

`SymmetricJWTValidator` validates JWTs signed with HMAC shared secrets
(`HS256`, `HS384`, `HS512`). This is common in server-to-server scenarios
where both sides share a secret.

```python {linenums="1"}
from guardpost.jwts import SymmetricJWTValidator

validator = SymmetricJWTValidator(
    valid_issuers=["https://auth.example.com/"],
    valid_audiences=["my-api"],
    secret_key="my-super-secret-key",   # str, bytes, or Secret
    algorithms=["HS256"],
)

claims = await validator.validate_jwt(raw_token)
print(claims["sub"])
```

/// admonition | Secret key types
    type: tip

`secret_key` accepts a plain `str`, `bytes`, or a `Secret` wrapper object,
so you can keep sensitive values out of your source code by reading them
from environment variables.
///

## `CompositeJWTValidator`

When your application must accept tokens from multiple issuers or signed with
different key types, use `CompositeJWTValidator`. It tries each validator in
order and returns the first successful result.

```python {linenums="1"}
from guardpost.jwts import (
    AsymmetricJWTValidator,
    CompositeJWTValidator,
    SymmetricJWTValidator,
)

validator = CompositeJWTValidator(
    AsymmetricJWTValidator(
        valid_issuers=["https://external-idp.com/"],
        valid_audiences=["my-api"],
        authority="https://external-idp.com/",
    ),
    SymmetricJWTValidator(
        valid_issuers=["https://internal-service/"],
        valid_audiences=["my-api"],
        secret_key="internal-secret",
    ),
)

claims = await validator.validate_jwt(raw_token)
```

## Key sources

GuardPost supports three ways to supply public keys to `AsymmetricJWTValidator`.

=== "OpenID Connect authority"

    The most common approach. Provide the issuer URL and GuardPost will
    automatically discover the JWKS URI from the `.well-known/openid-configuration`
    endpoint.

    ```python {linenums="1"}
    validator = AsymmetricJWTValidator(
        valid_issuers=["https://login.microsoftonline.com/tenant-id/v2.0"],
        valid_audiences=["api://my-app-id"],
        authority="https://login.microsoftonline.com/tenant-id/v2.0",
    )
    ```

=== "Direct JWKS URL"

    Provide the JWKS endpoint URL directly, bypassing discovery.

    ```python {linenums="1"}
    validator = AsymmetricJWTValidator(
        valid_issuers=["https://auth.example.com/"],
        valid_audiences=["my-api"],
        keys_url="https://auth.example.com/.well-known/jwks.json",
    )
    ```

=== "Custom keys provider"

    Implement `KeysProvider` or use `InMemoryKeysProvider` for testing.

    ```python {linenums="1"}
    from guardpost.jwts import AsymmetricJWTValidator
    from guardpost.jwks import JWKS, JWK, InMemoryKeysProvider

    # Build a provider from a raw JWKS dict (e.g. loaded from a file)
    jwks_dict = {
        "keys": [
            {
                "kty": "RSA",
                "kid": "my-key-1",
                "use": "sig",
                "n": "<base64url-modulus>",
                "e": "AQAB",
            }
        ]
    }
    jwks = JWKS.from_dict(jwks_dict)
    provider = InMemoryKeysProvider(jwks)

    validator = AsymmetricJWTValidator(
        valid_issuers=["https://auth.example.com/"],
        valid_audiences=["my-api"],
        keys_provider=provider,
    )
    ```

## The `require_kid` parameter

By default, `AsymmetricJWTValidator` rejects tokens that do not contain a
`kid` (Key ID) header claim. This is a security best practice: `kid` lets the
validator select the correct key from the JWKS and avoids trying all available
keys.

```python {linenums="1"}
validator = AsymmetricJWTValidator(
    valid_issuers=["https://auth.example.com/"],
    valid_audiences=["my-api"],
    authority="https://auth.example.com/",
    require_kid=False,  # accept tokens without a kid header
)
```

/// admonition | When to disable `require_kid`
    type: warning

Only set `require_kid=False` when your identity provider does not include `kid`
in tokens. This forces GuardPost to try every key in the JWKS, which is slower
and slightly less secure.
///

## Caching behaviour

Fetching JWKS over HTTP on every token validation would be slow. GuardPost
caches keys automatically:

- After the first fetch, keys are cached for `cache_time` seconds (default 3 hours).
- When `cache_time - refresh_time` seconds have passed, a background refresh is
  triggered proactively to avoid downtime during key rotation.
- If a token carries an unknown `kid`, the cache is bypassed immediately and
  the JWKS endpoint is re-queried. This handles key rotation without waiting
  for the cache to expire.

```python {linenums="1"}
validator = AsymmetricJWTValidator(
    valid_issuers=["https://auth.example.com/"],
    valid_audiences=["my-api"],
    authority="https://auth.example.com/",
    cache_time=3600,   # cache keys for 1 hour
    refresh_time=60,   # start refreshing 1 minute before expiry
)
```

## Exceptions

| Exception | When raised |
|-----------|-------------|
| `InvalidAccessToken` | The JWT is malformed, the signature is invalid, or the claims are wrong |
| `ExpiredAccessToken` | The JWT has a valid signature but is past its `exp` claim |

`ExpiredAccessToken` is a subclass of `InvalidAccessToken`, so you can catch
either or both.

```python {linenums="1"}
from guardpost.jwts import ExpiredAccessToken, InvalidAccessToken

try:
    claims = await validator.validate_jwt(raw_token)
except ExpiredAccessToken:
    # Tell the client to refresh their token
    print("Token has expired.")
except InvalidAccessToken as exc:
    # The token is bad — reject the request
    print(f"Invalid token: {exc}")
```

## Real-world example: popular identity providers

/// admonition | Supported identity providers
    type: info

GuardPost has been tested with the following identity providers:

- **Auth0** — `authority="https://<your-domain>.auth0.com/"`
- **Azure Active Directory** — `authority="https://login.microsoftonline.com/<tenant-id>/v2.0"`
- **Azure AD B2C** — `authority="https://<tenant>.b2clogin.com/<tenant>.onmicrosoft.com/<policy>/v2.0"`
- **Okta** — `authority="https://<your-okta-domain>/oauth2/default"`
///

=== "Auth0"

    ```python {linenums="1"}
    from guardpost.jwts import AsymmetricJWTValidator

    validator = AsymmetricJWTValidator(
        valid_issuers=["https://my-tenant.auth0.com/"],
        valid_audiences=["https://my-api.example.com"],
        authority="https://my-tenant.auth0.com/",
        algorithms=["RS256"],
    )
    ```

=== "Azure AD"

    ```python {linenums="1"}
    from guardpost.jwts import AsymmetricJWTValidator

    TENANT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    APP_ID    = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"

    validator = AsymmetricJWTValidator(
        valid_issuers=[
            f"https://login.microsoftonline.com/{TENANT_ID}/v2.0",
            f"https://sts.windows.net/{TENANT_ID}/",
        ],
        valid_audiences=[f"api://{APP_ID}"],
        authority=f"https://login.microsoftonline.com/{TENANT_ID}/v2.0",
        algorithms=["RS256"],
    )
    ```

=== "Okta"

    ```python {linenums="1"}
    from guardpost.jwts import AsymmetricJWTValidator

    validator = AsymmetricJWTValidator(
        valid_issuers=["https://my-org.okta.com/oauth2/default"],
        valid_audiences=["api://default"],
        authority="https://my-org.okta.com/oauth2/default",
        algorithms=["RS256"],
    )
    ```

## Using the validator as an `AuthenticationHandler`

`AsymmetricJWTValidator` and `SymmetricJWTValidator` implement the
`AuthenticationHandler` interface, so they can be plugged directly into
`AuthenticationStrategy`:

```python {linenums="1"}
from guardpost import AuthenticationStrategy
from guardpost.jwts import AsymmetricJWTValidator


class MockContext:
    def __init__(self, authorization: str | None = None):
        self.authorization = authorization
        self.identity = None

    @property
    def token(self) -> str | None:
        if self.authorization and self.authorization.startswith("Bearer "):
            return self.authorization[7:]
        return None


validator = AsymmetricJWTValidator(
    valid_issuers=["https://auth.example.com/"],
    valid_audiences=["my-api"],
    authority="https://auth.example.com/",
)

strategy = AuthenticationStrategy(validator)
# strategy.authenticate(context) will parse and validate the Bearer token
```
