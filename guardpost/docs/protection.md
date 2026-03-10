# Brute-force Protection

This page describes GuardPost's built-in brute-force protection feature,
including:

- [X] Overview of the protection feature
- [X] `InvalidCredentialsError`
- [X] `RateLimiter` class — configuration and thresholds
- [X] Integration with `AuthenticationStrategy`
- [X] Custom storage backends

## Overview

Brute-force attacks against authentication endpoints (login forms, API key
checks, etc.) are a common threat. GuardPost provides a `RateLimiter` that
automatically tracks failed authentication attempts and blocks a client after
a configurable threshold is exceeded.

The mechanism works as follows:

1. Your `AuthenticationHandler` raises `InvalidCredentialsError` when presented
   with wrong credentials.
2. `AuthenticationStrategy` catches this exception, increments the failure
   counter for the client, and re-raises (or blocks) as appropriate.
3. Once the failure count reaches the threshold, subsequent requests from the
   same client are rejected immediately without even calling the handler.

## `InvalidCredentialsError`

`InvalidCredentialsError` is a subclass of `AuthenticationError`. Raise it
inside an `AuthenticationHandler` whenever you detect that credentials are
present but invalid (wrong password, revoked key, etc.).

```python {linenums="1"}
from guardpost import AuthenticationHandler, Identity
from guardpost.protection import InvalidCredentialsError


class PasswordHandler(AuthenticationHandler):
    scheme = "Basic"

    async def authenticate(self, context) -> None:
        username = getattr(context, "username", None)
        password = getattr(context, "password", None)

        if username and password:
            if self._check_credentials(username, password):
                context.identity = Identity(
                    {"sub": username}, self.scheme
                )
            else:
                # Signal a failed attempt — the rate limiter will count this
                raise InvalidCredentialsError(f"Invalid password for '{username}'")

    def _check_credentials(self, username: str, password: str) -> bool:
        # Replace with a real database lookup
        return username == "alice" and password == "correct-password"
```

/// admonition | Why a dedicated exception?
    type: info

Using `InvalidCredentialsError` (rather than simply leaving `context.identity`
as `None`) lets `AuthenticationStrategy` distinguish between
_"no credentials provided"_ (anonymous request — don't count) and
_"wrong credentials provided"_ (brute-force attempt — do count).
///

## `RateLimiter`

`RateLimiter` stores per-client failure counters and exposes a `check` method
that blocks clients that exceed the threshold.

```python {linenums="1"}
from guardpost.protection import RateLimiter

limiter = RateLimiter(
    max_attempts=5,      # allow up to 5 failures before blocking
    duration=300,        # time window in seconds (5 minutes)
)
```

| Parameter      | Type  | Default | Description                                    |
| -------------- | ----- | ------- | ---------------------------------------------- |
| `max_attempts` | `int` | `5`     | Max failures allowed within `duration` seconds |
| `duration`     | `int` | `300`   | Time window in seconds for the failure counter |

By default, counters are stored **in memory** — they do not persist across
process restarts and are not shared between multiple processes. This is
sufficient for single-process applications. See
[Custom storage backends](#custom-storage-backends) for distributed setups.

## Integration with `AuthenticationStrategy`

Pass a `RateLimiter` instance to `AuthenticationStrategy` to enable
brute-force protection automatically.

```python {linenums="1"}
import asyncio
from guardpost import AuthenticationHandler, AuthenticationStrategy, Identity
from guardpost.protection import InvalidCredentialsError, RateLimiter


class MockContext:
    def __init__(self, username=None, password=None, client_ip="127.0.0.1"):
        self.username = username
        self.password = password
        self.client_ip = client_ip
        self.identity = None

    # The rate limiter uses this property to identify the client
    @property
    def client_id(self) -> str:
        return self.client_ip


class PasswordHandler(AuthenticationHandler):
    scheme = "Basic"

    async def authenticate(self, context: MockContext) -> None:
        if context.username and context.password:
            if context.username == "alice" and context.password == "s3cr3t":
                context.identity = Identity(
                    {"sub": context.username}, self.scheme
                )
            else:
                raise InvalidCredentialsError("Bad credentials.")


async def main():
    limiter = RateLimiter(max_attempts=3, duration=60)
    strategy = AuthenticationStrategy(PasswordHandler(), rate_limiter=limiter)

    # Simulate repeated failures from the same IP
    for attempt in range(4):
        ctx = MockContext(username="alice", password="wrong", client_ip="10.0.0.1")
        try:
            await strategy.authenticate(ctx)
        except Exception as exc:
            print(f"Attempt {attempt + 1}: {type(exc).__name__} — {exc}")


asyncio.run(main())
```

Expected output:

```
Attempt 1: InvalidCredentialsError — Bad credentials.
Attempt 2: InvalidCredentialsError — Bad credentials.
Attempt 3: InvalidCredentialsError — Bad credentials.
Attempt 4: TooManyRequestsError — Too many failed attempts from 10.0.0.1
```

/// admonition | Client identification
    type: tip

The rate limiter identifies clients using `context.client_id` if the property
exists, otherwise it falls back to the string representation of the context.
In web frameworks like BlackSheep, `client_id` is automatically mapped to the
client IP address.
///

## Custom storage backends

The default in-memory storage is suitable for single-process applications. For
distributed systems (multiple workers or processes), you need a shared store
such as Redis.

You can implement a custom backend by subclassing `RateLimiter` and overriding
the `get_attempts` / `increment_attempts` methods:

```python {linenums="1"}
from guardpost.protection import RateLimiter


class RedisRateLimiter(RateLimiter):
    def __init__(self, redis_client, **kwargs):
        super().__init__(**kwargs)
        self._redis = redis_client

    async def get_attempts(self, client_id: str) -> int:
        value = await self._redis.get(f"guardpost:attempts:{client_id}")
        return int(value) if value else 0

    async def increment_attempts(self, client_id: str) -> int:
        key = f"guardpost:attempts:{client_id}"
        count = await self._redis.incr(key)
        if count == 1:
            # Set TTL on first increment
            await self._redis.expire(key, self.duration)
        return count
```
