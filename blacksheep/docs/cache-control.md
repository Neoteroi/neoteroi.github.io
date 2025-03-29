BlackSheep offers features to configure `Cache-Control` response headers.
This page explains:

- [X] How to use the `cache_control` decorator to configure a header for specific
  request handlers
- [X] How to use the `CacheControlMiddleware` to configure a common header for all
  request handlers globally

## About Cache-Control

The `Cache-Control` response header can be used to describe how responses can
be cached by clients. For information on this subject, it is recommended to
refer to the [`mozilla.org` documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control).

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

```

!!! warning "Decorators order"
    The order of decorators matters: the router decorator must be the outermost
    decorator in this case.

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

The provided `CacheControlMiddleware` can be subclassed to control what requests
should be affected:

```python
from blacksheep import Request, Response
from blacksheep.server.headers.cache import CacheControlMiddleware


class MyCacheControlMiddleware(CacheControlMiddleware):
    def should_handle(self, request: Request, response: Response) -> bool:
        # TODO: implement here the desired logic
        ...
```

For example, a middleware that disables cache-control by default can be defined in the following way:

```python
class NoCacheControlMiddleware(CacheControlMiddleware):
    """
    Disable client caching globally, by default, setting a
    Cache-Contro: no-cache, no-store for all responses.
    """

    def __init__(self) -> None:
        super().__init__(no_cache=True, no_store=True)

    def should_handle(self, request: Request, response: Response) -> bool:
        return True
```
