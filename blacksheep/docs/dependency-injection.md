# Dependency injection in BlackSheep
The getting started tutorials show how route and query string parameters can be
injected directly in request handlers, by function signature. BlackSheep
also supports dependency injection of services configured for the application.
This page describes:

- [X] An introduction to dependency injection in BlackSheep, with a focus on `rodi`.
- [X] Service resolution.
- [X] Service lifetime.
- [X] Options to create services.
- [X] Examples of dependency injection.
- [X] How to use alternatives to `rodi`.

## Introduction

The `Application` object exposes a `services` property that can be used to
configure services. When the function signature of a request handler references
a type that is registered as a service, an instance of that type is
automatically injected when the request handler is called.

Consider this example:

* some context is necessary to handle certain web requests (for example, a
  database connection pool)
* a class that contains this context can be configured in application services
  before the application starts
* request handlers have this context automatically injected

### Demo

Starting from a minimal environment as described in the [getting started
tutorial](../getting-started/), create a `foo.py` file with the following
contents, inside a `domain` folder:

```
.
├── domain
│   ├── foo.py
│   └── __init__.py
└── server.py
```

**domain/foo.py**:
```python
class Foo:

    def __init__(self) -> None:
        self.foo = "Foo"
```

Import the new class in `server.py`, and register the type in `app.services`
as in this example:

**server.py**:
```python
from blacksheep import Application, get

from domain.foo import Foo


app = Application()

app.services.add_scoped(Foo)  # <-- register Foo type as a service


@get("/")
def home(foo: Foo):  # <-- foo is referenced in type annotation
    return f"Hello, {foo.foo}!"

```

An instance of `Foo` is injected automatically for every web request to "/".

Dependency injection is implemented in a dedicated library from the same author:
[`rodi`](https://github.com/RobertoPrevato/rodi). `rodi` implements dependency
injection in an unobtrusive way: it works by inspecting `__init__` methods and
doesn't require altering the source code of classes registered as services.
`rodi` can also resolve dependencies by inspecting class annotations, if an
`__init__` method is not specified for the class to activate.

## Service resolution

`rodi` automatically resolves graphs of services, when a type that is resolved
requires other types. In the following example, instances of `A` are created
automatically when resolving `Foo` because the `__init__` method in `Foo`
requires an instance of `A`:

**foo.py**:
```python
class A:
    def __init__(self) -> None:
        pass


class Foo:
    def __init__(self, a: A) -> None:
        self.a = a
```

Note that both types need to be registered in `app.services`:

**server.py**:
```python
from blacksheep import Application, get, text

from domain.foo import A, Foo


app = Application()

app.services.add_transient(A)
app.services.add_scoped(Foo)


@get("/")
def home(foo: Foo):
    return text(
        f"""
        A: {id(foo.a)}
        """
    )

```

Produces a response like the following at "/":

```
        A: 140289521293056
```

## Using class annotations

An alternative to defining `__init__` methods is to use class annotations, like
in the example below:

```python
class A:
    pass


class Foo:
    a: A
```

## Understanding service lifetimes

`rodi` supports services having one of these lifetimes:

* __singleton__ - instantiated only once per service provider
* __transient__ - services are instantiated every time they are required
* __scoped__ - instantiated once per web request

Consider the following example, where a type `A` is registered as transient,
`B` as scoped, `C` as singleton:

**foo.py**:
```python
class A:
    def __init__(self) -> None:
        pass


class B:
    def __init__(self) -> None:
        pass


class C:
    def __init__(self) -> None:
        pass


class Foo:
    def __init__(self, a1: A, a2: A, b1: B, b2: B, c1: C, c2: C) -> None:
        self.a1 = a1
        self.a2 = a2
        self.b1 = b1
        self.b2 = b2
        self.c1 = c1
        self.c2 = c2

```

**server.py**:
```python
from blacksheep import Application, get, text

from domain.foo import A, B, C, Foo


app = Application()

app.services.add_transient(A)
app.services.add_scoped(B)
app.services.add_singleton(C)

app.services.add_scoped(Foo)


@get("/")
def home(foo: Foo):
    return text(
        f"""
        A1: {id(foo.a1)}

        A2: {id(foo.a2)}

        B1: {id(foo.b1)}

        B2: {id(foo.b2)}

        C1: {id(foo.c1)}

        C2: {id(foo.c2)}
        """
    )

```

Produces responses like the following at "/":

**Request 1**:
```
        A1: 139976289977296

        A2: 139976289977680

        B1: 139976289977584

        B2: 139976289977584

        C1: 139976289978736

        C2: 139976289978736
```

**Request 2**:
```
        A1: 139976289979888

        A2: 139976289979936

        B1: 139976289979988

        B2: 139976289979988

        C1: 139976289978736

        C2: 139976289978736
```

Note how:

- transient services are always instantiated whenever they are activated (A)
- scoped services are instantiated once per web request (B)
- a singleton service is activated only once (C)

## Options to create services

`rodi` provides several ways to define and instantiate services.

1. registering an exact instance as a singleton
2. registering a concrete class by its type
3. registering an abstract class and one of its concrete implementations
4. registering a service using a factory function

#### Singleton example

```python

class ServiceSettings:
    def __init__(
        self,
        oauth_application_id: str,
        oauth_application_secret: str
    ):
        self.oauth_application_id = oauth_application_id
        self.oauth_application_secret = oauth_application_secret

app.services.add_instance(ServiceSettings("00000000001", "APP_SECRET_EXAMPLE"))

```

#### Registering a concrete class

```python

class HelloHandler:

    def __init__(self):
        pass

    def greetings() -> str:
        return "Hello"


app.services.add_transient(HelloHandler)

```

#### Registering an abstract class

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional

from blacksheep.server.responses import json, not_found


# domain class and abstract repository defined in a dedicated package for
# domain objects
@dataclass
class Cat:
    id: str
    name: str


class CatsRepository(ABC):

    @abstractmethod
    async def get_cat_by_id(self, id: str) -> Optional[Cat]:
        pass

# ------------------

# the concrete implementation will be defined in a dedicated package
class PostgreSQLCatsRepository(CatsRepository):

    async def get_cat_by_id(self, id: str) -> Optional[Cat]:
        # TODO: implement
        raise Exception("Not implemented")

# ------------------

# register the abstract class and its concrete implementation when configuring
# the application
app.services.add_scoped(CatsRepository, PostgreSQLCatsRepository)


# a request handler needing the CatsRepository doesn't need to know about
# the exact implementation (e.g. PostgreSQL, SQLite, etc.)
@get("/api/cats/{cat_id}")
async def get_cat(cat_id: str, repo: CatsRepository):

    cat = await repo.get_cat_by_id(cat_id)

    if cat is None:
        return not_found()

    return json(cat)

```

#### Using a factory function

```python
class Something:
    def __init__(self, value: str) -> None:
        self.value = value


def something_factory(services, activating_type) -> Something:
    return Something("Factory Example")


app.services.add_transient_by_factory(something_factory)
```

#### Example: implement a request context
A good example of a scoped service is one used to assign each web request with
a trace id that can be used to identify requests for logging purposes.

```python
from uuid import UUID, uuid4


class OperationContext:
    def __init__(self):
        self._trace_id = uuid4()

    @property
    def trace_id(self) -> UUID:
        return self._trace_id

```

Register the `OperationContext` type as a scoped service, this way it is
instantiated once per web request:

```python

app.services.add_scoped(OperationContext)


@get("/")
def home(context: OperationContext):
    return text(
        f"""
        Request ID: {context.trace_id}
        """
    )

```

## Services that require asynchronous initialization

Services that require asynchronous initialization can be configured inside
`on_start` callbacks, like in the following example:

```python
import asyncio
from blacksheep import Application, get, text


app = Application()


class Example:
    def __init__(self, text):
        self.text = text


async def configure_something(app: Application):
    await asyncio.sleep(0.5)  # simulate 500 ms delay

    app.services.add_instance(Example("Hello World"))


app.on_start += configure_something


@get("/")
async def home(service: Example):
    return service.text

```

Services configured this way are automatically injected in request handlers
when a parameter name or type annotation matches a key inside `app.services`.

Services that require disposing of should be disposed of in `on_stop` callback:

```python
async def dispose_example(app: Application):
    # Note: after the application is started, services are read from
    # app.service_provider:

    service = app.service_provider[Example]
    await service.dispose()


app.on_stop += dispose_example
```

## The container protocol

Since version 2, BlackSheep supports alternatives to `rodi` for dependency
injection. The `services` property of the `Application` class needs to conform
to the following container protocol:

- `register` method to register types
- `resolve` method to resolve instances of types
- `__contains__` method to describe whether a type is defined inside the container

```python
class ContainerProtocol:
    """
    Generic interface of DI Container that can register and resolve services,
    and tell if a type is configured.
    """

    def register(self, obj_type: Union[Type, str], *args, **kwargs):
        """Registers a type in the container, with optional arguments."""

    def resolve(self, obj_type: Union[Type[T], str], *args, **kwargs) -> T:
        """Activates an instance of the given type, with optional arguments."""

    def __contains__(self, item) -> bool:
        """
        Returns a value indicating whether a given type is configured in this container.
        """
```

The following example shows how to use
[`punq`](https://github.com/bobthemighty/punq) for dependency injection instead
of `rodi`, and how a transient service can be resolved at "/" and a singleton
service resolved at "/home":

```python
from typing import Type, TypeVar, Union, cast

import punq

from blacksheep import Application
from blacksheep.messages import Request
from blacksheep.server.controllers import Controller, get

T = TypeVar("T")


class Foo:
    def __init__(self) -> None:
        self.foo = "Foo"


class PunqDI:
    """
    BlackSheep DI container implemented with punq

    https://github.com/bobthemighty/punq
    """
    def __init__(self, container: punq.Container) -> None:
        self.container = container

    def register(self, obj_type, *args):
        self.container.register(obj_type, *args)

    def resolve(self, obj_type: Union[Type[T], str], *args) -> T:
        return cast(T, self.container.resolve(obj_type))

    def __contains__(self, item) -> bool:
        return bool(self.container.registrations[item])


container = punq.Container()
container.register(Foo)

app = Application(services=PunqDI(container), show_error_details=True)


@get("/")
def home(foo: Foo):  # <-- foo is referenced in type annotation
    return f"Hello, {foo.foo}!"


class Settings:
    def __init__(self, greetings: str):
        self.greetings = greetings


container.register(Settings, instance=Settings("example"))


class Home(Controller):
    def __init__(self, settings: Settings):
        # controllers are instantiated dynamically at every web request
        self.settings = settings

    async def on_request(self, request: Request):
        print("[*] Received a request!!")

    def greet(self):
        return self.settings.greetings

    @get("/home")
    async def index(self):
        return self.greet()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="localhost", port=44777, log_level="debug")
```

It is also possible to configure the dependency injection container using the
`settings` namespace, like in the following example:

```python
from blacksheep.settings.di import di_settings


def default_container_factory():
    return PunqDI(punq.Container())


di_settings.use(default_container_factory)
```

!!! danger "Dependency injection libraries vary"
    Some features might not be supported when using a different kind of container,
    because not all libraries for dependency injection implement the notion of
    `singleton`, `scoped`, and `transient` (most only implement `singleton` and
    `transient`).
