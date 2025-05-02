# Dependency injection in BlackSheep

The getting started tutorials demonstrate how route and query string parameters
can be directly injected into request handlers through function signatures.
Additionally, BlackSheep supports the dependency injection of services
configured for the application. This page covers:

- [X] An introduction to dependency injection in BlackSheep, with a focus on Rodi.
- [X] Service resolution.
- [X] Service lifetime.
- [X] Options to create services.
- [X] Examples of dependency injection.
- [X] How to use alternatives to Rodi.

/// admonition | Rodi's documentation
Detailed documentation for Rodi can be found at: [_Rodi_](/rodi/).
///

## Introduction

The `Application` object exposes a `services` property that can be used to configure services. When the function signature of a request handler references a type that is registered as a service, an instance of that type is automatically injected when the request handler is called.

Consider this example:

* Some context is necessary to handle certain web requests (for example, a
  database connection pool).
* A class that contains this context can be configured in application services
  before the application starts.
* Request handlers have this context automatically injected.

### Demo

Starting from a minimal environment as described in the [getting started
tutorial](getting-started.md), create a `foo.py` file with the following
contents, inside a `domain` folder:

```
.
├── domain
│   ├── __init__.py
│   └── foo.py
└── server.py
```

```python
# domain/foo.py
class Foo:

    def __init__(self) -> None:
        self.foo = "Foo"
```

Import the new class in `server.py`, and register the type in `app.services`
as in this example:

```python {hl_lines="9 13"}
# server.py
from blacksheep import Application, get

from domain.foo import Foo


app = Application()

app.services.add_scoped(Foo)  # <-- register Foo type as a service


@get("/")
def home(foo: Foo):  # <-- foo is referenced in type annotation
    return f"Hello, {foo.foo}!"
```

An instance of `Foo` is injected automatically for every web request to "/".

Dependency injection is implemented in a dedicated library:
[Rodi](https://github.com/neoteroi/rodi). Rodi implements dependency injection
in an unobtrusive way: it works by inspecting code and doesn't require altering
the source code of the types it resolves.

## Service resolution

Rodi automatically resolves dependency graphs when a resolved type depends on
other types. In the following example, instances of `A` are automatically
created when resolving `Foo` because the `__init__` method in `Foo` requires an
instance of `A`:

```python {hl_lines="2 7"}
# domain/foo.py
class A:
    pass


class Foo:
    def __init__(self, dependency: A) -> None:
        self.dependency = dependency
```

Both types must be registered in `app.services`:

```python {hl_lines="9-10"}
# server.py
from blacksheep import Application, get, text

from domain.foo import A, Foo


app = Application()

app.services.add_transient(A)
app.services.add_scoped(Foo)


@get("/")
def home(foo: Foo):
    return text(
        f"""
        A: {id(foo.dependency)}
        """
    )
```

Produces a response like the following at "/":

```
        A: 140289521293056
```

## Using class annotations

It is possible to use class properties, like in the example below:

```python {hl_lines="6"}
class A:
    pass


class Foo:
    dependency: A
```

## Understanding service lifetimes

`rodi` supports types having one of these lifetimes:

* __singleton__ - instantiated only once.
* __transient__ - services are instantiated every time they are required.
* __scoped__ - instantiated once per web request.

Consider the following example, where a type `A` is registered as transient,
`B` as scoped, `C` as singleton:

```python
# domain/foo.py
class A:
    ...


class B:
    ...


class C:
    ...


class Foo:
    def __init__(self, a1: A, a2: A, b1: B, b2: B, c1: C, c2: C) -> None:
        self.a1 = a1
        self.a2 = a2
        self.b1 = b1
        self.b2 = b2
        self.c1 = c1
        self.c2 = c2

```

```python
# server.py
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

=== "Request 1"
    ```
            A1: 139976289977296

            A2: 139976289977680

            B1: 139976289977584

            B2: 139976289977584

            C1: 139976289978736

            C2: 139976289978736
    ```

=== "Request 2"
    ```
            A1: 139976289979888

            A2: 139976289979936

            B1: 139976289979988

            B2: 139976289979988

            C1: 139976289978736

            C2: 139976289978736
    ```

- Transient services are created every time they are needed (A).
- Scoped services are created once per web request (B).
- Singleton services are instantiated only once and reused across the application (C).

## Options to create services

Rodi provides several ways to define and instantiate services.

1. registering an exact instance as a singleton
2. registering a concrete class by its type
3. registering an abstract class and one of its concrete implementations
4. registering a service using a factory function

For detailed information on this subject, refer to the Rodi documentation:
[_Registering types_](https://www.neoteroi.dev/rodi/registering-types/).

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

app.services.add_instance(
    ServiceSettings("00000000001", os.environ["OAUTH_APP_SECRET"])
)

```

#### Registering a concrete class

```python

class HelloHandler:

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
    return text(f"Request ID: {context.trace_id}")
```

## Services that require asynchronous initialization

Services that require asynchronous initialization can be configured using
application events. The recommended way is using the `lifespan` context
manager, like described in the example below.

```python {linenums="1" hl_lines="9 15-16 18 22"}
import asyncio
from blacksheep import Application
from blacksheep.client.pool import ClientConnectionPools
from blacksheep.client.session import ClientSession

app = Application()


@app.lifespan
async def register_http_client():
    async with ClientSession(
        pools=ClientConnectionPools(asyncio.get_running_loop())
    ) as client:
        print("HTTP client created and registered as singleton")
        app.services.register(ClientSession, instance=client)
        yield

    print("HTTP client disposed of")


@router.get("/")
async def home(http_client: ClientSession):
    print(http_client)
    return {"ok": True, "client_instance_id": id(http_client)}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=44777, log_level="debug", lifespan="on")
```

Here are the key points describing the logic of using the `lifespan` decorator:

- **Purpose**: The `@app.lifespan` decorator is used to define asynchronous
  setup and teardown logic for an application, such as initializing and
  disposing of resources.
- **Setup Phase**: Code before the `yield` statement is executed when the
  application starts. This is typically used to initialize resources (e.g.,
  creating an HTTP client, database connections, or other services).
- **Resource Registration**: During the setup phase, resources can be
  registered as services in the application's dependency injection container,
  making them available for injection into request handlers.
- **Teardown Phase**: Code after the `yield` statement is executed when the
  application stops. This is used to clean up or dispose of resources (e.g.,
  closing connections or releasing memory).
- **Singleton Resource Management**: The `@lifespan` decorator is particularly
  useful for managing singleton resources that need to persist for the
  application's lifetime.
- **Example Use Case**: In the provided example, an `HTTP client` is created
  and registered as a singleton during the setup phase, and it is disposed of
  during the teardown phase.

---

Otherwise, it is possible to use the `on_start` callback, like in the following
example, to register a service that requires asynchronous initialization:

```python {hl_lines="13-19"}
import asyncio
from blacksheep import Application, get, text


app = Application()


class Example:
    def __init__(self, text):
        self.text = text


async def configure_something(app: Application):
    await asyncio.sleep(0.5)  # simulate 500 ms delay

    # Note: this works with Rodi! If you use a different kind of DI,
    # implement the desired logic in your connector object / ContainerProtocor
    app.services.add_instance(Example("Hello World"))


app.on_start += configure_something


@get("/")
async def home(service: Example):
    return service.text

```

Services that require disposal can be disposed of in the `on_stop` callback:

```python {hl_lines="3 6"}
async def dispose_example(app: Application):
    service = app.services.resolve(Example)
    await service.dispose()


app.on_stop += dispose_example
```

## The container protocol

Since version 2, BlackSheep supports alternatives to `rodi` for dependency
injection. The `services` property of the `Application` class needs to conform
to the following container protocol:

- The `register` method to register types.
- The `resolve` method to resolve instances of types.
- The `__contains__` method to describe whether a type is defined inside the
  container.

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

### Using Punq instead of Rodi

The following example demonstrates how to use
[`punq`](https://github.com/bobthemighty/punq) for dependency injection as an
alternative to `rodi`.

```python {hl_lines="17 36-37 39"}
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

/// admonition | Dependency injection libraries vary.
    type: danger

Some features might not be supported when using a different kind of container,
because not all libraries for dependency injection implement the notion of
`singleton`, `scoped`, and `transient` (most only implement `singleton` and
`transient`).

///

### Using Dependency Injector instead of Rodi

The following example illustrates how to use [Dependency Injector](https://python-dependency-injector.ets-labs.org/) instead of Rodi.

```python {linenums="1" hl_lines="3 19-24 31 40-41 43 75 84 95-100"}
from typing import Type, TypeVar, get_type_hints

from dependency_injector import containers, providers

from blacksheep import Application, get

T = TypeVar("T")


class APIClient: ...


class SomeService:

    def __init__(self, api_client: APIClient) -> None:
        self.api_client = api_client


# Define the Dependency Injector container
class AppContainer(containers.DeclarativeContainer):
    APIClient = providers.Singleton(APIClient)
    SomeService = providers.Factory(
        SomeService, api_client=APIClient
    )


# Create the container instance
container = AppContainer()


class DependencyInjectorConnector:
    """
    This class connects a Dependency Injector container with a
    BlackSheep application.
    Dependencies are registered using the code API offered by
    Dependency Injector. The BlackSheep application activates services
    using the container when needed.
    """

    def __init__(self, container: containers.Container) -> None:
        self._container = container

    def register(self, obj_type: Type[T]) -> None:
        """
        Registers a type with the container.
        The code below inspects the object's constructor's types annotations to
        automatically configure the provider to activate the type.

        It is not necessary to use @inject or Provide core on the __init__ method. This
        helps reducing code verbosity and keeping the source code not polluted by DI
        specific code.
        """
        constructor = getattr(obj_type, "__init__", None)

        if not constructor:
            raise ValueError(
                f"Type {obj_type.__name__} does not have an __init__ method."
            )

        # Get the type hints for the constructor parameters
        type_hints = get_type_hints(constructor)

        # Exclude 'self' from the parameters
        dependencies = {
            param_name: getattr(self._container, param_type.__name__)
            for param_name, param_type in type_hints.items()
            if param_name not in {"self", "return"}
            and hasattr(self._container, param_type.__name__)
        }

        # Create a provider for the type with its dependencies
        provider = providers.Factory(obj_type, **dependencies)
        setattr(self._container, obj_type.__name__, provider)

    def resolve(self, obj_type: Type[T], _) -> T:
        """Resolves an instance of the given type."""
        provider = getattr(self._container, obj_type.__name__, None)
        if provider is None:
            raise TypeError(
                f"Type {obj_type.__name__} is not registered in the container."
            )
        return provider()

    def __contains__(self, item: Type[T]) -> bool:
        """Checks if a type is registered in the container."""
        return hasattr(self._container, item.__name__)


app = Application(
    services=DependencyInjectorConnector(container), show_error_details=True
)


@get("/")
def home(service: SomeService):
    print(service)
    # DependencyInjector resolved the dependencies
    assert isinstance(service, SomeService)
    assert isinstance(service.api_client, APIClient)
    return id(service)

```

**Notes:**

- By using **composition**, we can integrate a third-party dependency injection
  library like `dependency_injector` into BlackSheep without tightly coupling
  the framework to the library.
- We need a class like `DependencyInjectorConnector` that acts as a
  bridge between `dependency_injector` and BlackSheep.
- When wiring dependencies for your application, you use the code API offered
  by **Dependency Injector**.
- BlackSheep remains agnostic about the specific dependency injection library
  being used, but it needs the interface provided by the connector.
- In this case, **Dependency Injector** _Provide_ and _@inject_ constructs are
  not needed on request handlers because BlackSheep handles the injection of
  parameters into request handlers and infers when it needs to resolve a type
  using the provided _connector_.

In the example above, the name of the properties must match the type names
simply because `DependencyInjectorConnector` is obtaining `providers` by exact
type names. We could easily follow the convention of using **snake_case** or
a more robust approach of obtaining providers by types by changing the
connector's logic.

The connector can resolve types for controllers' `__init__` methods:

```python
class APIClient: ...


class SomeService:

    def __init__(self, api_client: APIClient) -> None:
        self.api_client = api_client


class AnotherService: ...


# Define the Dependency Injector container
class AppContainer(containers.DeclarativeContainer):
    APIClient = providers.Singleton(APIClient)
    SomeService = providers.Factory(SomeService, api_client=APIClient)
    AnotherService = providers.Factory(AnotherService)


class TestController(Controller):

    def __init__(self, another_dep: AnotherService) -> None:
        super().__init__()
        self._another_dep = (
            another_dep  # another_dep is resolved by Dependency Injector
        )

    @app.controllers_router.get("/controller-test")
    def controller_test(self, service: SomeService):
        # DependencyInjector resolved the dependencies
        assert isinstance(self._another_dep, AnotherService)

        assert isinstance(service, SomeService)
        assert isinstance(service.api_client, APIClient)
        return id(service)
```

_[Full example](https://github.com/Neoteroi/BlackSheep-Examples/blob/main/dependency-injector/main.py)._

/// admonition | :snake: Examples.
    type: hint

The [_BlackSheep-Examples_](https://github.com/Neoteroi/BlackSheep-Examples/blob/main/dependency-injector/). repository contains examples for integrating with
_Dependency Injector_, including an example illustrating how to use `snake_case` for providers in
the Dependency Injector's container: [_BlackSheep-Examples_](https://github.com/Neoteroi/BlackSheep-Examples/blob/main/dependency-injector/docs/example2.py).

///
