# Binders

BlackSheep implements automatic binding of parameters for request handlers, a
feature inspired by "Model Binding" in the [ASP.NET web
framework](https://docs.microsoft.com/en-us/aspnet/core/mvc/models/model-binding?view=aspnetcore-2.2).
This feature improves code quality and the developer experience since it
provides a strategy to read values from request objects in a consistent way and
removes the need to write parts that read values from the request object inside
request handlers. It also enables a more accurate generation of [OpenAPI
Documentation](openapi.md), since the framework is aware of what kind of
parameters are used by the request handlers (e.g. _headers, cookies, query_).

This page describes:

- [X] Implicit and explicit bindings.
- [X] Built-in binders.
- [X] How to define a custom binder.

It is recommended to read the following pages before this one:

* [Getting started: Basics](getting-started.md)
* [Getting started: MVC](mvc-project-template.md)
* [Requests](requests.md)

## Introduction

Automatic binding of request query strings and route parameters has been
described in several places in the previous pages, and explicit and implicit
binding is introduced in the section about [requests](requests.md).

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
(see [_Service resolution_](dependency-injection.md#service-resolution) for
more information on services that depend on other services).

`input` is obtained by reading the request payload, parsing it as JSON, and
creating an instance of CreateCatInput from it. If an exception occurs while
trying to parse the request payload or when instantiating the `CreateCatInput`,
the framework produces automatically a `400 Bad Request` response for the client.

When mapping the request's payload to an instance of the desired type, the type
is instantiated using `cls(**data)`. If it necessary to parse dates or other
complex types that are not handled by JSON deserialization, this must be done
in the constructor of the class. To handle gracefully a JSON payload having
extra unused properties, use `**kwargs` in your class constructor: `__init__(one,
two, three, **kwargs)`.

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

## Custom Convert Functions in BoundValue Classes

Since version `2.4.1`, custom `BoundValue` classes can define a `convert` class method
to transform Python objects from parsed JSON into more specific types. This is
particularly useful when you need to apply custom validation or transformation logic
during the binding process.

### Defining a Convert Function

To add custom conversion logic to a `BoundValue` class, define a `convert` class method:

```python
from typing import Any, Dict
from blacksheep import Application, FromJSON, post
from blacksheep.server.bindings import BoundValue

class CustomData(BoundValue[Dict[str, Any]]):
    """
    Custom bound value with conversion logic.
    """

    @classmethod
    def convert(cls, value: Any) -> Dict[str, Any]:
        """
        Convert the parsed JSON value into the desired format.
        This method is called after JSON parsing but before creating the BoundValue
        instance.
        """
        if isinstance(value, dict):
            # Apply custom validation and transformation
            if 'required_field' not in value:
                raise ValueError("Missing required_field in request data")

            # Transform the data
            return {
                'processed': True,
                'original': value,
                'timestamp': value.get('timestamp', 'default_value')
            }

        raise ValueError("Expected a dictionary object")

app = Application()

@post("/api/data")
async def process_data(data: FromJSON[CustomData]):
    # data.value contains the converted dictionary
    return {
        "received": data.value,
        "processed": data.value['processed']
    }
```

### Advanced Custom Conversion

You can implement more complex conversion logic for specific use cases:

```python
from dataclasses import dataclass
from datetime import datetime
from typing import Optional
from blacksheep import FromJSON, post
from blacksheep.server.bindings import BoundValue

@dataclass
class UserProfile:
    name: str
    email: str
    created_at: datetime
    age: Optional[int] = None

class UserProfileBinder(BoundValue[UserProfile]):
    """
    Custom binder that converts JSON to UserProfile with date parsing.
    """

    @classmethod
    def convert(cls, value: Any) -> UserProfile:
        if not isinstance(value, dict):
            raise ValueError("Expected a dictionary for UserProfile")

        # Parse the datetime string
        created_at_str = value.get('created_at')
        if isinstance(created_at_str, str):
            try:
                created_at = datetime.fromisoformat(created_at_str)
            except ValueError:
                raise ValueError("Invalid datetime format for created_at")
        else:
            created_at = datetime.utcnow()

        # Validate required fields
        if not value.get('name') or not value.get('email'):
            raise ValueError("Name and email are required fields")

        return UserProfile(
            name=value['name'],
            email=value['email'],
            created_at=created_at,
            age=value.get('age')
        )

@post("/api/users")
async def create_user(profile: FromJSON[UserProfileBinder]):
    user = profile.value  # This is a UserProfile instance
    return {
        "message": f"User {user.name} created successfully",
        "user_id": hash(user.email),
        "created_at": user.created_at.isoformat()
    }
```

### Error Handling in Convert Functions

Convert functions should raise appropriate exceptions for invalid data:

```python
from blacksheep.server.bindings import BoundValue
from blacksheep.exceptions import BadRequest

class ValidatedInput(BoundValue[dict]):
    @classmethod
    def convert(cls, value: Any) -> dict:
        if not isinstance(value, dict):
            raise BadRequest("Expected JSON object")

        # Custom validation logic
        if 'id' not in value:
            raise BadRequest("Missing 'id' field")

        if not isinstance(value['id'], int) or value['id'] <= 0:
            raise BadRequest("Field 'id' must be a positive integer")

        return value
```

When the `convert` method raises an exception, BlackSheep automatically returns a `400
Bad Request` response with the error message.

/// admonition | Convert Method Behavior
    type: info

- It receives the parsed Python object (dict, list, etc.) as input.
- The return value becomes the `value` property of the `BoundValue` instance.
- Exceptions raised in `convert` methods are automatically converted to `400 Bad
  Request` responses.

///

## Type Converters

Since version `2.4.1`, BlackSheep provides a flexible type conversion system through the
`TypeConverter` abstract class. This system allows automatic conversion of string
representations from request parameters (query, headers, route, etc.) into specific
Python types.

### Built-in Type Converters

BlackSheep includes several built-in type converters that handle common data types:

| Converter           | Supported Types | Description                                       |
| ------------------- | --------------- | ------------------------------------------------- |
| `StrConverter`      | `str`           | Handles string values with URL decoding           |
| `BoolConverter`     | `bool`          | Converts "true"/"false", "1"/"0" to boolean       |
| `IntConverter`      | `int`           | Converts strings to integers                      |
| `FloatConverter`    | `float`         | Converts strings to floating-point numbers        |
| `UUIDConverter`     | `UUID`          | Converts strings to UUID objects                  |
| `BytesConverter`    | `bytes`         | Converts strings to bytes using UTF-8 encoding    |
| `DateTimeConverter` | `datetime`      | Parses ISO datetime strings                       |
| `DateConverter`     | `date`          | Parses ISO date strings                           |
| `StrEnumConverter`  | `StrEnum`       | Converts strings to StrEnum values (Python 3.11+) |
| `IntEnumConverter`  | `IntEnum`       | Converts strings to IntEnum values (Python 3.11+) |
| `LiteralConverter`  | `Literal`       | Validates against literal type values             |

### String Enum Support (Python 3.11+)

BlackSheep provides automatic support for `StrEnum` types:

```python
from enum import StrEnum
from blacksheep import Application, get

app = Application()

class Color(StrEnum):
    RED = "red"
    GREEN = "green"
    BLUE = "blue"

@get("/items")
async def get_items(color: Color):
    # color parameter automatically converted to Color enum
    return {"color": color.value, "name": color.name}

# Usage examples:
# GET /items?color=red        -> Color.RED
# GET /items?color=GREEN      -> Color.GREEN (by name)
# GET /items?color=invalid    -> 400 Bad Request
```

### Integer Enum Support (Python 3.11+)

Similarly, `IntEnum` types are automatically supported:

```python
from enum import IntEnum
from blacksheep import Application, get

class Priority(IntEnum):
    LOW = 1
    MEDIUM = 2
    HIGH = 3

@get("/tasks")
async def get_tasks(priority: Priority):
    return {"priority": priority.value, "name": priority.name}

# Usage examples:
# GET /tasks?priority=1       -> Priority.LOW
# GET /tasks?priority=HIGH    -> Priority.HIGH (by name)
# GET /tasks?priority=5       -> 400 Bad Request
```

### Literal Type Support

BlackSheep supports `typing.Literal` for restricting values to specific literals:

```python
from typing import Literal
from blacksheep import Application, get

@get("/api/data")
async def get_data(format: Literal["json", "xml", "csv"]):
    return {"format": format, "message": f"Returning data in {format} format"}

# Usage examples:
# GET /api/data?format=json   -> format="json"
# GET /api/data?format=pdf    -> 400 Bad Request

# Case-insensitive literal matching
from blacksheep.server.bindings.converters import LiteralConverter

# Configure case-insensitive matching (if needed globally)
# This would require custom binder configuration
```

### Custom Type Converter

You can define custom type converters by implementing the `TypeConverter` abstract class:

```python
from abc import abstractmethod
from blacksheep.server.bindings.converters import TypeConverter
from blacksheep.server.bindings.converters import converters
from blacksheep import Application, get

# Custom type example
class ProductCode:
    def __init__(self, code: str):
        if not code.startswith("PROD-"):
            raise ValueError("Product code must start with 'PROD-'")
        if len(code) != 10:
            raise ValueError("Product code must be exactly 10 characters")
        self.code = code

    def __str__(self):
        return self.code

# Custom converter
class ProductCodeConverter(TypeConverter):
    def can_convert(self, expected_type) -> bool:
        return expected_type is ProductCode

    def convert(self, value, expected_type):
        if value is None:
            return None
        try:
            return ProductCode(value)
        except ValueError as e:
            raise ValueError(f"Invalid product code: {e}")

# Register the custom converter
converters.append(ProductCodeConverter())

app = Application()

@get("/products/{product_code}")
async def get_product(product_code: ProductCode):
    return {"product_code": str(product_code)}

# Usage examples:
# GET /products/PROD-12345  -> ProductCode("PROD-12345")
# GET /products/INVALID     -> 400 Bad Request
```

### Advanced Converter Configuration

For more complex scenarios, you can configure converters with custom options:

```python
from blacksheep.server.bindings.converters import LiteralConverter
from blacksheep import FromQuery, get

# Case-insensitive literal converter
case_insensitive_converter = LiteralConverter(case_insensitive=True)

class CustomFromQuery(FromQuery[T]):
    def __init__(self, default_value=None):
        super().__init__(default_value)
        # Custom converter logic could be added here

@get("/search")
async def search(
    sort_order: Literal["asc", "desc"] = "asc",
    category: Literal["books", "movies", "games"] = "books"
):
    # Both parameters support case-insensitive matching if configured
    return {"sort_order": sort_order, "category": category}
```

### Error Handling in Type Conversion

When type conversion fails, BlackSheep automatically returns a `400 Bad Request` response:

```python
from enum import StrEnum
from blacksheep import Application, get

class Status(StrEnum):
    ACTIVE = "active"
    INACTIVE = "inactive"

@get("/users")
async def get_users(status: Status):
    return {"status": status}

# GET /users?status=invalid -> 400 Bad Request with message:
# "invalid is not a valid Status"
```

### Type Converter Priority

Converters are evaluated in the order they appear in the `converters` list. Built-in
converters are registered by default, and custom converters are typically appended to
the list.

```python
from blacksheep.server.bindings.converters import converters

# View all registered converters
for converter in converters:
    print(f"{converter.__class__.__name__}: {converter}")

# Add custom converter with priority (insert at beginning)
converters.insert(0, YourCustomConverter())
```
