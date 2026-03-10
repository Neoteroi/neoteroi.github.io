# JWKS and Key Types

This page covers GuardPost's JWKS (JSON Web Key Sets) API, including:

- [X] `KeyType` enum
- [X] The `JWK` dataclass
- [X] The `JWKS` dataclass — parsing and updating
- [X] `InMemoryKeysProvider`
- [X] `URLKeysProvider`
- [X] `AuthorityKeysProvider`
- [X] `CachingKeysProvider` — TTL and automatic refresh
- [X] Supported EC curves

## `KeyType` enum

`KeyType` enumerates the supported key types:

| Value | Description |
|-------|-------------|
| `KeyType.RSA` | RSA keys (used with RS256, RS384, RS512) |
| `KeyType.EC` | Elliptic Curve keys (used with ES256, ES384, ES512) |
| `KeyType.OCT` | Octet sequence / symmetric keys (used with HS256, HS384, HS512) |
| `KeyType.OKP` | Octet Key Pair (e.g. Ed25519) |

```python {linenums="1"}
from guardpost.jwks import KeyType

print(KeyType.RSA)   # KeyType.RSA
print(KeyType.EC)    # KeyType.EC
```

## The `JWK` dataclass

`JWK` represents a single JSON Web Key. The fields depend on the key type:

| Field | Key type | Description |
|-------|----------|-------------|
| `kty` | all | Key type string (`"RSA"`, `"EC"`, `"oct"`) |
| `pem` | all | The key material as PEM-encoded bytes |
| `kid` | optional | Key ID |
| `n` | RSA | Base64url-encoded modulus |
| `e` | RSA | Base64url-encoded public exponent |
| `crv` | EC | Curve name (`"P-256"`, `"P-384"`, `"P-521"`) |
| `x` | EC | Base64url-encoded x coordinate |
| `y` | EC | Base64url-encoded y coordinate |

### Parsing from a dict

```python {linenums="1"}
from guardpost.jwks import JWK

# RSA key
rsa_jwk = JWK.from_dict({
    "kty": "RSA",
    "kid": "rsa-key-1",
    "use": "sig",
    "n": "sT6MoYl9dkMnMzT3eLzFfYjpY3oN...",
    "e": "AQAB",
})
print(rsa_jwk.kid)   # "rsa-key-1"
print(rsa_jwk.kty)   # "RSA"

# EC key
ec_jwk = JWK.from_dict({
    "kty": "EC",
    "kid": "ec-key-1",
    "crv": "P-256",
    "x": "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
    "y": "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0",
})
print(ec_jwk.crv)  # "P-256"
```

### Building RSA and EC PEMs from raw parameters

GuardPost exposes helper functions for building PEM-encoded keys from raw
base64url parameters — useful when you receive individual key parameters
instead of a full JWKS document.

```python {linenums="1"}
from guardpost.jwks import rsa_pem_from_n_and_e, ec_pem_from_x_y_crv

# Build an RSA public key PEM from base64url modulus and exponent
rsa_pem: bytes = rsa_pem_from_n_and_e(
    n="sT6MoYl9dkMnMzT3...",
    e="AQAB",
)

# Build an EC public key PEM from base64url x, y and curve name
ec_pem: bytes = ec_pem_from_x_y_crv(
    x="f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
    y="x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0",
    crv="P-256",
)
```

## The `JWKS` dataclass

`JWKS` represents a complete JSON Web Key Set — a collection of `JWK` objects.

### Parsing from a dict

```python {linenums="1"}
from guardpost.jwks import JWKS

raw = {
    "keys": [
        {
            "kty": "RSA",
            "kid": "key-1",
            "use": "sig",
            "n": "sT6MoYl9dkMnMzT3...",
            "e": "AQAB",
        },
        {
            "kty": "EC",
            "kid": "key-2",
            "crv": "P-256",
            "x": "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
            "y": "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0",
        },
    ]
}

jwks = JWKS.from_dict(raw)
print(len(jwks.keys))    # 2
print(jwks.keys[0].kid)  # "key-1"
```

### Updating a key set

`JWKS.update(new_set)` merges the keys from another `JWKS` into the current
one, replacing existing keys that share the same `kid`.

```python {linenums="1"}
from guardpost.jwks import JWKS

existing = JWKS.from_dict({"keys": [{"kty": "RSA", "kid": "k1", "n": "...", "e": "AQAB"}]})
updated  = JWKS.from_dict({"keys": [{"kty": "RSA", "kid": "k2", "n": "...", "e": "AQAB"}]})

existing.update(updated)
# existing now contains both k1 and k2
```

## `InMemoryKeysProvider`

`InMemoryKeysProvider` wraps a static `JWKS` object. Use it in tests or when
you pre-load keys from configuration.

```python {linenums="1"}
from guardpost.jwks import JWKS, InMemoryKeysProvider
from guardpost.jwts import AsymmetricJWTValidator

jwks = JWKS.from_dict({
    "keys": [
        {"kty": "RSA", "kid": "k1", "n": "...", "e": "AQAB"}
    ]
})

provider = InMemoryKeysProvider(jwks)

validator = AsymmetricJWTValidator(
    valid_issuers=["https://auth.example.com/"],
    valid_audiences=["my-api"],
    keys_provider=provider,
)
```

## `URLKeysProvider`

`URLKeysProvider` fetches a JWKS document from a URL on demand. Use it when
your identity provider exposes a dedicated JWKS endpoint without an OpenID
Connect discovery document.

```python {linenums="1"}
from guardpost.jwks import URLKeysProvider
from guardpost.jwts import AsymmetricJWTValidator

provider = URLKeysProvider("https://auth.example.com/.well-known/jwks.json")

validator = AsymmetricJWTValidator(
    valid_issuers=["https://auth.example.com/"],
    valid_audiences=["my-api"],
    keys_provider=provider,
)
```

## `AuthorityKeysProvider`

`AuthorityKeysProvider` uses OpenID Connect discovery to locate the JWKS URI
automatically. Provide the issuer URL and it will fetch
`<authority>/.well-known/openid-configuration`, parse the `jwks_uri` field,
and retrieve the key set from there.

```python {linenums="1"}
from guardpost.jwks import AuthorityKeysProvider
from guardpost.jwts import AsymmetricJWTValidator

provider = AuthorityKeysProvider("https://login.microsoftonline.com/tenant/v2.0")

validator = AsymmetricJWTValidator(
    valid_issuers=["https://login.microsoftonline.com/tenant/v2.0"],
    valid_audiences=["api://my-app"],
    keys_provider=provider,
)
```

/// admonition | Shorthand
    type: tip

Passing `authority="..."` to `AsymmetricJWTValidator` automatically creates
an `AuthorityKeysProvider` internally. You only need to create one manually
if you want to compose it with `CachingKeysProvider`.
///

## `CachingKeysProvider`

`CachingKeysProvider` wraps any other `KeysProvider` and adds TTL-based
caching. This avoids hammering the JWKS endpoint on every token validation.

Key features:

- Keys are cached for `cache_time` seconds after each fetch.
- When the cache age exceeds `cache_time - refresh_time`, a background refresh
  is triggered proactively.
- If a token's `kid` is not found in the cached set, the cache is bypassed
  and the JWKS endpoint is queried immediately, supporting seamless key rotation.

```python {linenums="1"}
from guardpost.jwks import AuthorityKeysProvider, CachingKeysProvider
from guardpost.jwts import AsymmetricJWTValidator

inner_provider = AuthorityKeysProvider("https://auth.example.com/")

caching_provider = CachingKeysProvider(
    provider=inner_provider,
    cache_time=3600,   # cache for 1 hour
    refresh_time=120,  # refresh 2 minutes before expiry
)

validator = AsymmetricJWTValidator(
    valid_issuers=["https://auth.example.com/"],
    valid_audiences=["my-api"],
    keys_provider=caching_provider,
)
```

/// admonition | Default caching
    type: info

When you use the `authority` or `keys_url` shorthand on `AsymmetricJWTValidator`,
caching is set up automatically with the `cache_time` and `refresh_time`
parameters you provide (defaulting to 10800 s and 120 s respectively).
///

## Supported EC curves

| Curve | JWT algorithm | Description |
|-------|---------------|-------------|
| `P-256` | `ES256` | 256-bit NIST curve (most common) |
| `P-384` | `ES384` | 384-bit NIST curve |
| `P-521` | `ES512` | 521-bit NIST curve |

```python {linenums="1"}
from guardpost.jwks import JWK

p256 = JWK.from_dict({"kty": "EC", "crv": "P-256", "x": "...", "y": "..."})
p384 = JWK.from_dict({"kty": "EC", "crv": "P-384", "x": "...", "y": "..."})
p521 = JWK.from_dict({"kty": "EC", "crv": "P-521", "x": "...", "y": "..."})
```
