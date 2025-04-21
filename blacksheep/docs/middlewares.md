# Middlewares

Middlewares enable modifying the chain of functions that handle each web
request.

This page covers:

- [X] Introduction to middlewares.
- [X] How to use function decorators to avoid code repetition.

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

!!! warning
    The `ensure_response` function is necessary to support scenarios
    when the request handlers defined by the user doesn't return an instance of
    Response class (see _[request handlers normalization](request-handlers.md)_).
