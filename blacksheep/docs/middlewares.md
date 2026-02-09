# Middlewares

Middlewares enable modifying the chain of functions that handle each web
request.

This page covers:

- [X] Introduction to BlackSheep middlewares.
- [X] How to use function decorators to avoid code repetition.
- [X] Middleware management with MiddlewareList and MiddlewareCategory.
- [X] Organizing middlewares by categories and priorities.
- [X] How to integrate ASGI middlewares.

## Introduction to middlewares

Middlewares enable the definition of callbacks that are executed for each web
request in a specific order.

!!! info
    If a function should only be called for specific routes, use
    a [decorator function](middlewares.md#wrapping-request-handlers) instead.

Middlewares are executed in order: each receives the `Request` object as the
first parameter and the next handler to be called as the second parameter. Any
middleware can choose not to call the next handler and instead return a
`Response` object. For instance, a middleware can be used to return an `HTTP
401 Unauthorized` response in certain scenarios.

```python
from blacksheep import Application, get

app = Application()


async def middleware_one(request, handler):
    print("middleware 1: A")
    response = await handler(request)
    print("middleware 1: B")
    return response


async def middleware_two(request, handler):
    print("middleware 2: C")
    response = await handler(request)
    print("middleware 2: D")
    return response


app.middlewares.append(middleware_one)
app.middlewares.append(middleware_two)


@get("/")
def home():
    return "OK"
```

In this example, the following data would be printed to the console:

```
middleware 1: A
middleware 2: C
middleware 2: D
middleware 1: B
```

### Middlewares defined as classes

To define a middleware as a class, make the class async callable, like in the
example below:

```python
class ExampleMiddleware:

    async def __call__(self, request, handler):
        # do something before passing the request to the next handler

        response = await handler(request)

        # do something after the following request handlers prepared the response
        return response
```

The same example including type annotations:

```python
from typing import Awaitable, Callable

from blacksheep import Request, Response


class ExampleMiddleware:
    async def __call__(
        self, request: Request, handler: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        # do something before passing the request to the next handler

        response = await handler(request)

        # do something after the following request handlers prepared the response
        return response
```

### Resolution chains

When middlewares are defined for an application, resolution chains are built at
its start. Every handler configured in the application router is replaced by a
chain, executing middlewares in order, down to the registered handler.

## Middleware management

/// admonition | New in BlackSheep 2.4.4
    type: info

Starting from BlackSheep 2.4.4, middleware management has been enhanced with `MiddlewareList` and `MiddlewareCategory` to simplify middleware ordering and organization.

///

The `MiddlewareList` is a specialized container that provides better control over middleware ordering through categories and priorities. This addresses common issues where middleware order matters significantly, such as ensuring authentication happens before authorization, or that CORS headers are set early in the pipeline.

### Middleware categories

The `MiddlewareCategory` enum defines predefined categories that represent the typical order middlewares should be executed:

```python
from blacksheep.middlewares import MiddlewareCategory

# Available categories (in execution order):
MiddlewareCategory.INIT      # 10 - CORS, security headers, early configuration
MiddlewareCategory.SESSION   # 20 - Session handling
MiddlewareCategory.AUTH      # 30 - Authentication
MiddlewareCategory.AUTHZ     # 40 - Authorization
MiddlewareCategory.BUSINESS  # 50 - User business logic middlewares (default)
MiddlewareCategory.MESSAGE   # 60 - Request/Response modification
```

### Adding categorized middlewares

You can now specify a category and priority when adding middlewares:

```python
from blacksheep import Application
from blacksheep.middlewares import MiddlewareCategory

app = Application()

# Add middleware with category and priority
app.middlewares.append(
    cors_middleware,
    category=MiddlewareCategory.INIT,
    priority=0  # Lower priority = executed first within category
)

app.middlewares.append(
    auth_middleware,
    category=MiddlewareCategory.AUTH,
    priority=0
)

app.middlewares.append(
    custom_business_logic,
    category=MiddlewareCategory.BUSINESS,
    priority=10
)

# If no category is specified, defaults to BUSINESS
app.middlewares.append(logging_middleware)
```

### Priority within categories

Within each category, middlewares are ordered by their priority value (lower values execute first):

```python
# These will execute in order: middleware_a, middleware_b, middleware_c
app.middlewares.append(middleware_a, MiddlewareCategory.AUTH, priority=0)
app.middlewares.append(middleware_b, MiddlewareCategory.AUTH, priority=5)
app.middlewares.append(middleware_c, MiddlewareCategory.AUTH, priority=10)
```

### Backward compatibility

The traditional `append()` and `insert()` methods continue to work:

```python
# Traditional approach (still supported)
app.middlewares.append(my_middleware)

# Insert at specific position (defaults to INIT category for backward compatibility)
app.middlewares.insert(0, early_middleware)
```

### Example: Complete middleware setup

Here's a comprehensive example showing how to organize middlewares by category:

```python
from blacksheep import Application
from blacksheep.middlewares import MiddlewareCategory
from blacksheep.server.cors import CORSMiddleware
from blacksheep.server.authentication import AuthenticationMiddleware
from blacksheep.server.authorization import AuthorizationMiddleware

app = Application()

# CORS and security headers (execute first)
app.middlewares.append(
    CORSMiddleware(),
    category=MiddlewareCategory.INIT,
    priority=0
)

# Session handling
app.middlewares.append(
    session_middleware,
    category=MiddlewareCategory.SESSION,
    priority=0
)

# Authentication (after sessions)
app.middlewares.append(
    AuthenticationMiddleware(),
    category=MiddlewareCategory.AUTH,
    priority=0
)

# Authorization (after authentication)
app.middlewares.append(
    AuthorizationMiddleware(),
    category=MiddlewareCategory.AUTHZ,
    priority=0
)

# Custom business logic
app.middlewares.append(
    rate_limiting_middleware,
    category=MiddlewareCategory.BUSINESS,
    priority=0
)

app.middlewares.append(
    custom_logging_middleware,
    category=MiddlewareCategory.BUSINESS,
    priority=10
)

# Response modification (execute last)
app.middlewares.append(
    response_time_middleware,
    category=MiddlewareCategory.MESSAGE,
    priority=0
)
```

### Benefits of categorized middlewares

1. **Predictable ordering**: Middlewares execute in a logical, predictable order based on their category.
2. **Easier maintenance**: You can add middlewares without worrying about their position in a flat list.
3. **Better organization**: Categories make it clear what each middleware's purpose is.
4. **Flexible priorities**: Fine-tune execution order within categories using priority values.
5. **Backward compatibility**: Existing code continues to work without changes.

## Wrapping request handlers

When a common portion of logic should be applied to certain request handlers,
but not to all of them, it is recommended to define a decorator.

The following example shows how to define a decorator that applies certain
response headers only for certain routes.

```python
from functools import wraps
from typing import Tuple

from blacksheep.server.normalization import ensure_response


def headers(additional_headers: Tuple[Tuple[str, str], ...]):
    def decorator(next_handler):
        @wraps(next_handler)
        async def wrapped(*args, **kwargs) -> Response:
            response = ensure_response(await next_handler(*args, **kwargs))

            for (name, value) in additional_headers:
                response.add_header(name.encode(), value.encode())

            return response

        return wrapped

    return decorator
```

Then use the decorator on specific request handlers:

```python
@get("/")
@headers((("X-Foo", "Foo"),))
async def home():
    return "OK"
```

/// admonition | The order of decorators matters.
    type: warning

User-defined decorators must be applied before the route decorator (in the example above, before `@get`).

///

### Define a wrapper compatible with synchronous and asynchronous functions

To define a wrapper that is compatible with both synchronous and asynchronous
functions, it is possible to use `inspect.iscoroutinefunction` function. For
example, to alter the decorator above to be *also* compatible with request
handlers defined as synchronous functions:

```python {hl_lines="1 11"}
import inspect
from functools import wraps
from typing import Tuple

from blacksheep.server.normalization import ensure_response


def headers(additional_headers: Tuple[Tuple[str, str], ...]):
    def decorator(next_handler):

        if inspect.iscoroutinefunction(next_handler):
            @wraps(next_handler)
            async def wrapped(*args, **kwargs):
                response = ensure_response(await next_handler(*args, **kwargs))

                for (name, value) in additional_headers:
                    response.add_header(name.encode(), value.encode())

                return response

            return wrapped
        else:
            @wraps(next_handler)
            def wrapped(*args, **kwargs):
                response = ensure_response(next_handler(*args, **kwargs))

                for (name, value) in additional_headers:
                    response.add_header(name.encode(), value.encode())

                return response

            return wrapped

    return decorator
```

/// admonition | Additional dependencies.
    type: warning

The `ensure_response` function is necessary to support scenarios
when the request handlers defined by the user doesn't return an instance of
Response class (see _[request handlers normalization](request-handlers.md)_).

///

## How to integrate ASGI middlewares

BlackSheep middlewares cannot be mixed with ASGI middlewares because they use different
code APIs. However, the `Application` class itself in BlackSheep supports the signature
of ASGI middlewares, and can be mixed with them at the application level instead of the
middleware chain level.

Consider the following example, where the `Starlette` `TrustedHostMiddleware` is used
with a BlackSheep application, following the pattern described in the Starlette
documentation at [_Using Middleware In Other Frameworks_](https://starlette.dev/middleware/#using-middleware-in-other-frameworks).

```python {hl_lines='12'}
from blacksheep import Application, get
from starlette.middleware.trustedhost import TrustedHostMiddleware


app = Application()


@get("/")
async def home():
    return "Hello!"

app = TrustedHostMiddleware(app, allowed_hosts=["localhost"])
```

Below is an example where `FastAPI-Events` is used with a BlackSheep application:

```python {hl_lines='27-30'}
from blacksheep import Application, get
from fastapi_events.dispatcher import dispatch
from fastapi_events.middleware import EventHandlerASGIMiddleware
from fastapi_events.handlers.local import LocalHandler
from fastapi_events.typing import Event


app = Application()


async def handle_all_events(event: Event):
    """Handler for all events"""
    print(f"Event received: {event}")


# Create a local handler for events
local_handler = LocalHandler()
local_handler.register(handle_all_events)


@get("/")
async def home():
    dispatch("my-fancy-event", payload={"id": 1})  # Emit events anywhere in your code
    return "Hello!"


app = EventHandlerASGIMiddleware(
    app,
    handlers=[local_handler]
)
```

### Creating a custom application class for ASGI middleware management

While the direct wrapping approach shown above works well for simple cases, you may
want to create a custom application class if you need to manage multiple ASGI middlewares
or prefer a more explicit API that's consistent with BlackSheep's middleware system.

The following example shows how to define such a custom class that supports adding ASGI
middlewares through a dedicated method:

```python
# yourapp.py
from typing import Callable

from blacksheep import Application, Router
from blacksheep.server.routing import MountRegistry
from rodi import ContainerProtocol


class CustomApplication(Application):
    """
    Application subclass that supports ASGI middleware at the application level.

    ASGI middleware are applied before BlackSheep processes the request, providing
    a clean separation between ASGI-level and BlackSheep-level middleware.

    Usage:
        app = CustomApplication()

        # Add ASGI middleware (order matters - first added wraps outermost)
        app.add_asgi_middleware(some_asgi_middleware)
        app.add_asgi_middleware(another_asgi_middleware)
    """

    def __init__(
        self,
        *,
        router: Router | None = None,
        services: ContainerProtocol | None = None,
        show_error_details: bool = False,
        mount: MountRegistry | None = None,
    ):
        super().__init__(
            router=router,
            services=services,
            show_error_details=show_error_details,
            mount=mount,
        )
        self._asgi_chain = super().__call__
        self._asgi_middlewares: list[Callable] = []

    def add_asgi_middleware(self, middleware: Callable) -> None:
        """
        Adds an ASGI middleware to the application.

        The middleware should be a callable with signature:
            async def middleware(app, scope, receive, send) -> None

        Or a factory that returns such a callable:
            def middleware_factory(app) -> Callable

        Middleware are applied in the order they are added, with the first
        added being the outermost layer.

        Args:
            middleware: An ASGI middleware callable or factory
        """
        self._asgi_middlewares.append(middleware)

    async def start(self):
        self._asgi_chain = self._build_asgi_chain()
        return await super().start()

    async def __call__(self, scope, receive, send):
        return await self._asgi_chain(scope, receive, send)

    def _build_asgi_chain(self) -> Callable:
        """
        Builds the ASGI middleware chain, with the base Application.__call__
        as the innermost application.
        """
        # Start with the base application handler
        app = super().__call__

        # Wrap with each middleware in reverse order (last added wraps innermost)
        for middleware in reversed(self._asgi_middlewares):
            # Check if it's a factory (single parameter) or direct middleware
            import inspect
            sig = inspect.signature(middleware)
            params = list(sig.parameters.keys())

            # Factory pattern: middleware(app) -> callable (single parameter)
            if len(params) == 1:
                app = middleware(app)
            # Direct ASGI callable: needs to be wrapped
            elif len(params) == 3 and params == ['scope', 'receive', 'send']:
                # Wrap to provide app parameter
                wrapped_app = app
                async def asgi_wrapper(scope, receive, send, mw=middleware, inner=wrapped_app):
                    await mw(inner, scope, receive, send)
                app = asgi_wrapper  # type: ignore
            else:
                raise TypeError(
                    f"ASGI middleware must have signature (app, scope, receive, send) "
                    f"or be a factory with signature (app). Got: {sig}"
                )

        return app
```

The following example demonstrates how to use the custom `CustomApplication` class.
Notice the use of a lambda function to wrap the middleware initialization—this factory
pattern ensures the middleware receives the application instance correctly:

```python
from blacksheep import get
from fastapi_events.dispatcher import dispatch
from fastapi_events.middleware import EventHandlerASGIMiddleware
from fastapi_events.handlers.local import LocalHandler
from fastapi_events.typing import Event
from yourapp import CustomApplication


app = CustomApplication()


async def handle_all_events(event: Event):
    """Handler for all events"""
    print(f"Event received: {event}")


# Create a local handler for events
local_handler = LocalHandler()
local_handler.register(handle_all_events)


@get("/")
async def home():
    dispatch("my-fancy-event", payload={"id": 1})  # Emit events anywhere in your code
    return "Hello!"


# Note how the factory pattern is used below:
app.add_asgi_middleware(lambda app: EventHandlerASGIMiddleware(app, handlers=[local_handler]))
```
