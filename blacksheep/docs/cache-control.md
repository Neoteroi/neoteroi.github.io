This page describes features to configure `Cache-Control` response headers.
It covers:

- [X] Using the `cache_control` decorator to configure a header for specific
  request handlers.
- [X] Using the `CacheControlMiddleware` to configure a common header for all
  request handlers globally.
- [X] Support for field-specific directives using `list[str]` values.

## About Cache-Control

The `Cache-Control` response header can be used to describe how responses can
be cached by clients. For information on this subject, it is recommended to
refer to the [`mozilla.org` documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control).

## Field-specific cache directives

/// admonition | New in BlackSheep 2.4.4
    type: info

Starting from BlackSheep 2.4.4, the `no_cache` and `private` directives support `list[str]` values to specify field-specific caching rules. Earlier versions would require to handle multiple headers
using comma separated values like: `field1, field2`.

///

Some cache directives like `no-cache` and `private` can be applied to specific response fields. BlackSheep supports this through `list[str]` values:

```python
from blacksheep.server.headers.cache import cache_control

# Apply no-cache to specific headers
@cache_control(no_cache=["Set-Cookie", "Authorization"])
async def sensitive_endpoint():
    # This generates: Cache-Control: no-cache="Set-Cookie, Authorization"
    return "Sensitive data"

# Apply private directive to specific fields
@cache_control(private=["Set-Cookie"])
async def user_specific_endpoint():
    # This generates: Cache-Control: private="Set-Cookie"
    return "User-specific content"

# Boolean values still work as before
@cache_control(no_cache=True, no_store=True)
async def no_caching_endpoint():
    # This generates: Cache-Control: no-cache, no-store
    return "Never cache this"
```

When using `list[str]` values:

- **`no_cache=["field1", "field2"]`** → `no-cache="field1, field2"`
- **`private=["field1", "field2"]`** → `private="field1, field2"`
- **`no_cache=True`** → `no-cache` (applies to entire response)
- **`private=True`** → `private` (applies to entire response)

## Using the cache_control decorator

The following example illustrates how the `cache_control` decorator can be used
to control caching for specific request handlers:

```python
from blacksheep import Application, get
from blacksheep.server.headers.cache import cache_control


app = Application()


@get("/")
@cache_control(no_cache=True, no_store=True)
async def home():
    return "This response should not be cached or stored!"


@get("/api/cats")
@cache_control(max_age=120)
async def get_cats():
    ...


@get("/api/user-profile")
@cache_control(private=["Set-Cookie", "Authorization"])
async def get_user_profile():
    # Only Set-Cookie and Authorization headers are private
    return "User-specific data"


@get("/api/sensitive")
@cache_control(no_cache=["Authorization"], max_age=60)
async def get_sensitive_data():
    # Don't cache Authorization header, but allow 60s caching for other data
    return "Partially cacheable data"

```

/// admonition | Decorators order.
    type: warning

The order of decorators matters: the router decorator must be the outermost
decorator in this case.

///

For controllers:

```python
from blacksheep import Application
from blacksheep.server.controllers import Controller, get
from blacksheep.server.headers.cache import cache_control


app = Application()


class Home(Controller):
    @get("/")
    @cache_control(no_cache=True, no_store=True)
    async def index(self):
        return "Example"

```

## Using the CacheControlMiddleware

While the `cache_control` decorator described above can be used to configure
specific request handlers, in some circumstances it might be desirable to
configure a default `Cache-Control` strategy for all paths at once.

To configure a default `Cache-Control` for all `GET` request handlers resulting
in successful responses with status `200`.

```python
from blacksheep import Application
from blacksheep.server.controllers import Controller, get
from blacksheep.server.headers.cache import cache_control, CacheControlMiddleware


app = Application()


# Global cache control with field-specific directives
app.middlewares.append(
    CacheControlMiddleware(
        no_cache=["Set-Cookie", "Authorization"],
        max_age=300
    )
)

# Or traditional boolean approach
app.middlewares.append(CacheControlMiddleware(no_cache=True, no_store=True))
```

It is then possible to override the default rule in specific request handlers:

```python
app.middlewares.append(CacheControlMiddleware(no_cache=True, no_store=True))


class Home(Controller):
    @get("/")
    @cache_control(max_age=120)
    async def index(self):
        return "Example"
```

The provided `CacheControlMiddleware` can be subclassed to control when
requests should be affected:

```python
from blacksheep import Request, Response
from blacksheep.server.headers.cache import CacheControlMiddleware


class MyCacheControlMiddleware(CacheControlMiddleware):
    def should_handle(self, request: Request, response: Response) -> bool:
        # TODO: implement here the desired logic
        ...
```

For instance, a middleware that disables cache-control by default can be
defined in the following way:

```python
class NoCacheControlMiddleware(CacheControlMiddleware):
    """
    Disable client caching globally, by default, setting a
    Cache-Control: no-cache, no-store for all responses.
    """

    def __init__(self) -> None:
        super().__init__(no_cache=True, no_store=True)

    def should_handle(self, request: Request, response: Response) -> bool:
        return True
```
