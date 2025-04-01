# Binders
BlackSheep implements automatic binding of parameters for request handlers, a
feature inspired by "Model Binding" in the [ASP.NET web
framework](https://docs.microsoft.com/en-us/aspnet/core/mvc/models/model-binding?view=aspnetcore-2.2).
This feature improves code quality and the developer experience since it
provides a strategy to read values from request objects in a consistent way and
removes the need to write parts that read values from the request object inside
request handlers. It also enables a more accurate generation of [OpenAPI
Documentation](../openapi), since the framework is aware of what kind of
parameters are used by the request handlers (e.g. _headers, cookies, query_).

This page describes:

- [X] Implicit and explicit bindings.
- [X] Built-in binders.
- [X] How to define a custom binder.

It is recommended to read the following pages before this one:

* [Getting started: Basics](../getting-started/)
* [Getting started: MVC](../mvc-project-template/)
* [Requests](../requests/)

## Introduction

Automatic binding of request query strings and route parameters has been
described in several places in the previous pages, and explicit and implicit
binding is introduced in the section about [requests](../requests/).

Binding is implicit when the source of a parameter is inferred by conventions,
or explicit when the programmer specifies exact binders from
`blacksheep.server.bindings`.

### Implicit binding
An example of implicit binding is when a request handler parameter is read from
the request URL's route parameters because its name matches the name of a route
parameter:

```python
@get("/api/cats/{cat_id}")
async def get_cat(cat_id: str):
    ...
```

Another example of implicit binding is when a request handler parameter is
annotated with a type that is configured in `application.services`:

```python

class Foo:
    ...


app.services.add_instance(Foo())


@get("/something")
async def do_something(foo: Foo):
    ...
```

In this case, `Foo` is obtained from application services since the type is
registered in `app.services`.

Binding happens implicitly when parameters in the request handler's signature
are not annotated with types, or are **not** annotated with types that inherit
from `BoundValue` class, defined in `blacksheep.server.bindings`.

!!! warning
    A parameter with the name "request" is always bound to the instance of
    the `Request` of the web request.

### Explicit binding
Binders can be defined explicitly, using type annotations and classes from
`blacksheep.server.bindings` (or just `blacksheep`).

```python
from dataclasses import dataclass

from blacksheep import FromJSON, FromServices, post

from your_business_logic.handlers.cats import CreateCatHandler  # example


@dataclass
class CreateCatInput:
    name: str


@post("/api/cats")
async def create_cat(
    create_cat_handler: FromServices[CreateCatHandler],
    input: FromJSON[CreateCatInput],
):
    ...
```

In the example above, `create_cat_handler` is obtained from
`application.services`, an exception is thrown if the the service cannot be
resolved. This happens if the service is not registered in application
services, or any of the services on which it depends is not registered
(see [_Service resolution_](../dependency-injection/#service-resolution) for
more information on services that depend on other services).

`input` is obtained by reading the request payload, parsing it as JSON, and
creating an instance of CreateCatInput from it. If an exception occurs while
trying to parse the request payload or when instantiating the `CreateCatInput`,
the framework produces automatically a `400 Bad Request` response for the client.

When mapping the request's payload to an instance of the desired type, the type
is instantiated using `cls(**data)`. If it necessary to parse dates or other
complex types that are not handled by JSON deserialization, this must be done
in the constructor of the class. To handle gracefully a JSON payload having
extra unused properties, use `*args` in your class constructor: `__init__(one,
two, three, *args)`.

## Optional parameters
Optional parameters can be defined in one of these ways:

1. using `typing.Optional` annotation
1. specifying a default value


```python

@get("/foo")
async def example(
    page: int = 1,
    search: str = "",
):
    # page is read from the query string, if specified, otherwise defaults to 1
    # search is read from the query string, if specified, otherwise defaults to ""
    ...
```

```python
from typing import Optional


@get("/foo")
async def example(
    page: Optional[int],
    search: Optional[str],
):
    # page is read from the query string, if specified, otherwise defaults to None
    # search is read from the query string, if specified, otherwise defaults to None
    ...
```

```python
from blacksheep import FromQuery, get


@get("/foo")
async def example(
    page: FromQuery[int] = FromQuery(1),
    search: FromQuery[str] = FromQuery(""),
):
    # page.value defaults to 1
    # search.value defaults to ""
    ...
```

```python
from typing import Optional

from blacksheep import FromQuery, get


@get("/foo")
async def example(
    page: FromQuery[Optional[int]],
    search: FromQuery[Optional[str]],
):
    # page.value defaults to None
    # search.value defaults to None
    ...
```

```python
from typing import Optional

from blacksheep import FromQuery, get


@get("/foo")
async def example(
    page: Optional[FromQuery[int]],
    search: Optional[FromQuery[str]],
):
    # page defaults to None
    # search defaults to None
    ...
```

## Built-in binders

| Binder        | Description                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------------- |
| FromHeader    | A parameter obtained from a header.                                                                           |
| FromQuery     | A parameter obtained from URL query.                                                                          |
| FromCookie    | A parameter obtained from a cookie.                                                                           |
| FromServices  | Service from `application.services`.                                                                          |
| FromJSON      | Request body read as JSON and optionally parsed.                                                              |
| FromForm      | A parameter obtained from Form request body: either application/x-www-form-urlencoded or multipart/form-data. |
| FromText      | Request payload read as text, using UTF-8 encoding.                                                           |
| FromBytes     | Request payload read as raw bytes.                                                                            |
| FromFiles     | Request payload of file type.                                                                                 |
| ClientInfo    | Client IP and port information obtained from the request ASGI scope, as Tuple[str, int].                      |
| ServerInfo    | Server IP and port information obtained from the request scope.                                               |
| RequestUser   | Request's identity.                                                                                           |
| RequestURL    | Request's URL.                                                                                                |
| RequestMethod | Request's HTTP method.                                                                                        |

`FromHeader` and `FromCookie` binders must be subclassed because they require a
`name` class property:

```python
from blacksheep import FromCookie, FromHeader, get


class FromAcceptHeader(FromHeader[str]):
    name = "Accept"


class FromFooCookie(FromCookie[Optional[str]]):
    name = "foo"


@get("/")
def home(accept: FromAcceptHeader, foo: FromFooCookie) -> Response:
    return text(
        f"""
        Accept: {accept.value}
        Foo: {foo.value}
        """
    )
```

## Defining a custom binder

To define a custom binder, define a `BoundValue[T]` class and a `Binder`
class having `handle` class property referencing the custom `BoundValue` class.
The following example demonstrates how to define a custom binder:

```python
from typing import Optional

from blacksheep import Application, Request
from blacksheep.server.bindings import Binder, BoundValue

app = Application(show_error_details=True)
get = app.router.get


class FromCustomValue(BoundValue[str]):
    pass


class CustomBinder(Binder):

    handle = FromCustomValue

    async def get_value(self, request: Request) -> Optional[str]:
        # TODO: implement here the desired logic to read a value from
        # the request object
        return "example"


@get("/")
def home(something: FromCustomValue):
    assert something.value == "example"
    return f"OK {something.value}"

```
