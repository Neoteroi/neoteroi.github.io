# Request handlers

The previous pages explain that a request handler in BlackSheep is a function
associated with a route, responsible for handling web requests. This page
provides a detailed explanation of request handlers, covering the following
topics:

- [X] Request handler normalization.
- [X] Using asynchronous and synchronous code.

## Request handler normalization.

A standard request handler in BlackSheep is defined as an asynchronous function
with the following signature:

```python
from blacksheep import Request, Response

async def normal_handler(request: Request) -> Response:
    ...

```

For a function to act as a request handler, it must be associated with a route:

```python
from blacksheep import Application, Request, Response, get, text


app = Application()


@get("/")
async def normal_handler(request: Request) -> Response:
    return text("Example")
```

A request handler defined this way is called directly to generate a response
when a web request matches the route associated with the function (in this
case, HTTP GET at the root of the website "/").

To enhance the developer experience and improve development speed, BlackSheep
implements automatic normalization of request handlers. For instance, a request
handler can be defined as a synchronous function, and the framework will
automatically wrap it in an asynchronous wrapper:

```python

@get("/sync")
def sync_handler(request: Request) -> Response:
    return text("Example")

```

/// admonition | Avoid blocking code in synchronous methods!
    type: danger

When a request handler is defined as a synchronous function, BlackSheep assumes
that the developer understands asynchronous programming and intends for the
response to be returned immediately without performing I/O or CPU-intensive
operations that could block the event loop.

///

Similarly, request handlers are normalized when their function signature is
different than the normal one. For example, a request handler can be defined
without arguments, and returning a plain `str` or an instance of an object
(which gets serialized to `JSON` and configured as response content):

```python

@get("/greetings")
def hello_there() -> str:
    return "Hello, There!"

```

In the example below, the response content is JSON `{"id":1,"name":"Celine"}`:

```python
from dataclasses import dataclass


@dataclass
class Cat:
    id: int
    name: str


@get("/example-cat")
def get_example_cat() -> Cat:
    return Cat(1, "Celine")

```

### Automatic binding of parameters

An important feature enabled by function normalization is the automatic binding
of request parameters, as described in the `Getting Started` pages. Common
scenarios are using route parameters and query string parameters:

```python

# in this case, a route parameter is passed directly to the request handler
@get("/greetings/{name}")
def hello(name: str) -> str:
    return f"Hello, {name}!"


# in this case, query string parameters by name are read from the request and
# passed to the request handler
@get("/api/cats")
def get_cats(page: int = 1, page_size: int = 30, search: str = "") -> Response:
    ...

```

In the `get_cats` example above, function parameters are automatically read
from the query string and parsed if present; otherwise, default values are
used.

### Explicit and implicit binding

All examples so far showed how to use implicit binding of request parameters.
In the `get_cats` example above, all parameters are _implicitly_ bound from the
request query string. To enable more scenarios, BlackSheep also provides
explicit bindings that allow specifying the source of the parameter (e.g.
request headers, cookies, route, query, body, application services). In the
example below, `cat_input` is read automatically from the request payload as
JSON and deserialized automatically into an instance of the `CreateCatInput`
class.

```python
from dataclasses import dataclass

from blacksheep.server.bindings import FromJSON


@dataclass
class CreateCatInput:
    name: str
    ...


@post("/cat")
async def create_cat(
    cat_input: FromJSON[CreateCatInput]
):
    data = cat_input.value
    ...
```

More details about bindings are described in _[Binders](binders.md)_.

### Normalization and OpenAPI Documentation

Request handler normalization also enables a more accurate generation of
[OpenAPI Documentation](openapi.md), since the web framework knows that request
handlers need input from query strings, routes, headers, cookies, etc.; and
produce responses of a certain type.

## Using asynchronous and synchronous code.

BlackSheep supports both asynchronous and synchronous request handlers. Request
handlers don't need to be asynchronous in those scenarios when the response is
well-known and can be produced without doing any I/O bound operation or any
CPU-intensive operation. This is the case for example of redirects, and the
previous "Hello, There!" example:

```python
from blacksheep import Application, Request, Response, get, text, redirect


app = Application()


@get("/sync")
def sync_handler() -> str:
    return "Example Sync"

@get("/redirect-me")
def redirect_example() -> Response:
    return redirect("/sync")

```

Request handlers that perform I/O-bound or CPU-intensive operations should be
defined as `async` to avoid hindering the performance of the web server. For
example, if information is fetched from a database or a remote API when
handling a web request handler, it is correct to use asynchronous code to
reduce RAM consumption and not block the event loop of the web application.

/// admonition | CPU and I/O intensive operations.
    type: warning

If an operation is CPU-intensive (e.g. file operations or image resizing), the
request handlers that initiate such operation should be async, and use a
[thread or process
pool](https://docs.python.org/3/library/asyncio-eventloop.html#executing-code-in-thread-or-process-pools)
to not block the web app's event loop. Similarly, request handlers that
initiate I/O bound operations (e.g. web requests to external APIs, connecting
to a database) should also be `async`.

///

## Next

The next pages describe [requests](requests.md) and [responses](responses.md)
in detail.
