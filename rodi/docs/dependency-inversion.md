This page describes how to apply the [_Dependency Inversion Principle_](./getting-started.md#dependency-inversion-principle), working with _abstract_ classes, protocols,
and generics.

- [X] Working with interfaces.
- [X] Using abstract classes and protocols.
- [X] Working with generics.

## Working with interfaces

Abstract types are a way to define a common interface for a set of classes. This allows
you to write code that works with any class that implements the interface, without
needing to know the details of the implementation. When registering a type in a
`Container`, you can specify the base _interface_ which is used as _key_ to resolve
_concrete_ types, and the implementation type which is used to create the instance. This
is useful when it is desirable to use the same interface for different implementations,
or when you want to switch to a different implementation in the future without changing
the code that relies on the interface.

=== "add_transient"

    ```python {linenums="1", hl_lines="9 15 17"}
    from abc import ABC, abstractmethod
    from rodi import Container

    class MyInterface(ABC):
        @abstractmethod
        def do_something(self) -> str:
            pass

    class MyClass(MyInterface):
        def do_something(self) -> str:
            return "Hello, world!"

    container = Container()

    container.add_transient(MyInterface, MyClass)

    a1 = container.resolve(MyInterface)
    assert isinstance(a1, MyClass)
    assert a1.do_something() == "Hello, world!"
    ```

=== "add_singleton"

    ```python {linenums="1", hl_lines="9 15 17"}
    from abc import ABC, abstractmethod
    from rodi import Container

    class MyInterface(ABC):
        @abstractmethod
        def do_something(self) -> str:
            pass

    class MyClass(MyInterface):
        def do_something(self) -> str:
            return "Hello, world!"

    container = Container()

    container.add_singleton(MyInterface, MyClass)

    a1 = container.resolve(MyInterface)
    assert isinstance(a1, MyClass)
    assert a1.do_something() == "Hello, world!"
    ```

=== "add_scoped"

    ```python {linenums="1", hl_lines="9 15 17"}
    from abc import ABC, abstractmethod
    from rodi import Container

    class MyInterface(ABC):
        @abstractmethod
        def do_something(self) -> str:
            pass

    class MyClass(MyInterface):
        def do_something(self) -> str:
            return "Hello, world!"

    container = Container()

    container.add_scoped(MyInterface, MyClass)

    a1 = container.resolve(MyInterface)
    assert isinstance(a1, MyClass)
    assert a1.do_something() == "Hello, world!"
    ```

Using [`ABC` and `abstractmethod`](https://docs.python.org/3/library/abc.html)
is not strictly necessary, but it is recommended for defining interfaces.
This ensures that any class implementing the interface has the required methods.

If you decide on using a normal class to describe the interface, Rodi requires the
concrete class to be a subclass of the interface.

Otherwise, you can use a [`Protocol`](https://peps.python.org/pep-0544/) from the
`typing` module to define the interface. In this case, Rodi allows registering a
protocol as the interface and a normal class that does not inherit it (which aligns with
the original purpose of Python's `Protocol`).

The following examples work:

=== "Regular class (requires subclassing)"

    ```python {linenums="1", hl_lines="9 16 18"}
    from rodi import Container


    class MyInterface:
        def do_something(self) -> str:
            pass


    class MyClass(MyInterface):
        def do_something(self) -> str:
            return "Hello, world!"


    container = Container()

    container.add_transient(MyInterface, MyClass)

    a1 = container.resolve(MyInterface)
    assert isinstance(a1, MyClass)
    assert a1.do_something() == "Hello, world!"
    print(a1)
    ```

=== "Protocol (does not require subclassing)"

    ```python {linenums="1", hl_lines="10 17 19"}
    from typing import Protocol
    from rodi import Container


    class MyInterface(Protocol):
        def do_something(self) -> str:
            pass


    class MyClass:
        def do_something(self) -> str:
            return "Hello, world!"


    container = Container()

    container.add_transient(MyInterface, MyClass)

    a1 = container.resolve(MyInterface)
    assert isinstance(a1, MyClass)
    assert a1.do_something() == "Hello, world!"
    print(a1)
    ```

Rodi raises an exception if we try registering a normal class as interface, with a
concrete class that does not inherit it.

/// admonition | Protocols validation.
    type: warning

Rodi does **not** validate implementations of Protocols. This means that if you register
a class that does not implement the methods of the Protocol, Rodi will not raise an
exception. Support for Protocols validation might be added in the future, but for now,
you should ensure that the classes you register do implement the methods of the
Protocol.
///

---

## Note about factories

When using factories to define how abstract types are created, ensure the
factory's return type annotation specifies the _interface_.

```python {linenums="1", hl_lines="13-14 18"}
from abc import ABC, abstractmethod
from rodi import Container

class MyInterface(ABC):
    @abstractmethod
    def do_something(self) -> str:
        pass

class MyClass(MyInterface):
    def do_something(self) -> str:
        return "Hello, world!"

def my_factory() -> MyInterface:
    return MyClass()

container = Container()

container.add_transient_by_factory(my_factory)

a1 = container.resolve(A)
a2 = container.resolve(A)
assert isinstance(a1, A)
assert isinstance(a2, A)
assert a1 is not a2
```

/// admonition | Note about key types.
    type: danger

When working with abstract types, the _interface_ type (or _protocol_) must always be
used as the _key_ type. The implementation type is used to create the instance, but it
is not used as a key to resolve the type. This is according to the [_Dependency
Inversion Principle_](./getting-started.md#dependency-inversion-principle), which states
that high-level modules should not depend on low-level modules, but both should depend
on abstractions.

This is conceptually wrong:

```python {linenums="1", hl_lines="10"}
class MyInterface(ABC):
    @abstractmethod
    def do_something(self) -> str:
        pass

class MyClass(MyInterface):
    def do_something(self) -> str:
        return "Hello, world!"

def my_factory() -> MyClass:  # <-- No. This is a mistake.
    return MyClass()

container.add_transient_by_factory(my_factory)  # <-- MyClass is used as Key.
```

///

## Working with generics

Generic types are supported. The following example provides a demonstration of
generics with `TypeVar` in a real-world scenario.

```python {linenums="1", hl_lines="9 43-44 47-48"}
from dataclasses import dataclass
from typing import Generic, List, TypeVar

from rodi import Container

T = TypeVar("T")


class Repository(Generic[T]):
    """A generic repository for managing entities of type T."""

    def __init__(self):
        self._items: List[T] = []

    def add(self, item: T):
        """Add an item to the repository."""
        self._items.append(item)

    def get_all(self) -> List[T]:
        """Retrieve all items from the repository."""
        return self._items


# Define specific entity classes
@dataclass
class Product:
    id: int
    name: str


@dataclass
class Customer:
    id: int
    email: str
    first_name: str
    last_name: str


# Set up the container
container = Container()

# Register repositories
container.add_scoped(Repository[Product], Repository)
container.add_scoped(Repository[Customer], Repository)

# Resolve and use the repositories
product_repo = container.resolve(Repository[Product])
customer_repo = container.resolve(Repository[Customer])

# Add and retrieve products
product_repo.add(Product(1, "Laptop"))
product_repo.add(Product(2, "Smartphone"))
print(product_repo.get_all())

# Add and retrieve customers
customer_repo.add(Customer(1, "alice@wonderland.it", "Alice", "WhiteRabbit"))
customer_repo.add(Customer(1, "bob@foopower.it", "Bob", "TheHamster"))
print(customer_repo.get_all())
```

The above prints to screen:

```bash
[Product(id=1, name='Laptop'), Product(id=2, name='Smartphone')]
[Customer(id=1, email='alice@wonderland.it', first_name='Alice', last_name='WhiteRabbit'), Customer(id=1, email='bob@foopower.it', first_name='Bob', last_name='TheHamster')]
```

/// admonition | How to use instances of GenericAlias.
    type: warning

Note how the generics `Repository[Product]` and `Repository[Customer]` are both
configured to be resolved using `Repository` as concrete type. In Python,
instances of `GenericAlias` are not considered as actual classes. The following
wouldn't work:

```python
container.add_scoped(Repository[Product])  # No. 💥
container.add_scoped(Repository[Customer])  # No. 💥
```
///

### Nested generics

When working with nested generics, ensure that the *same type* used to describe
a dependency is registered in the container.

```python {linenums="1", hl_lines="12 16-17 26 33"}
from dataclasses import dataclass
from typing import Generic, List, TypeVar

from rodi import Container

T = TypeVar("T")


class DBConnection: ...


class Repository(Generic[T]):
    db_connection: DBConnection


class Service(Generic[T]):
    repository: Repository[T]


@dataclass
class Product:
    id: int
    name: str


class ProductsService(Service[Product]):
    ...


container = Container()

container.add_scoped(DBConnection)
container.add_scoped(Repository[T], Repository)
container.add_scoped(ProductsService)

service = container.resolve(ProductsService)
assert isinstance(service.repository, Repository)
assert isinstance(service.repository.db_connection, DBConnection)
```

---

The following wouldn't work, because the `Container` will look exactly for the
key `Repository[T]` when instantiating the `ProductsService`, not for
`Repository[Product]`:

```python
container.add_scoped(Repository[Product], Repository)  # No. 💥
```

Note that, in practice, this does not cause issues at runtime, because of
**type erasure**. For more information, refer to [_Instantiating generic classes and type erasure_](https://typing.python.org/en/latest/spec/generics.html#instantiating-generic-classes-and-type-erasure).

If you need to define a more specialized class for `Repository[Product]`,
because for example you need to define products-specific methods, you can:

- Define a `ProductsRepository(Repository[Product])`.
- Override the annotation for `repository` in `ProductsService`.
- Register `ProductsRepository` in the container.

```python {linenums="1", hl_lines="26 29-30 37"}
from dataclasses import dataclass
from typing import Generic, TypeVar

from rodi import Container

T = TypeVar("T")


class DBConnection: ...


class Repository(Generic[T]):
    db_connection: DBConnection


class Service(Generic[T]):
    repository: Repository[T]


@dataclass
class Product:
    id: int
    name: str


class ProductsRepository(Repository[Product]): ...


class ProductsService(Service[Product]):
    repository: ProductsRepository


container = Container()

container.add_scoped(DBConnection)
container.add_scoped(Repository[T], Repository)
container.add_scoped(ProductsRepository)
container.add_scoped(ProductsService)

service = container.resolve(ProductsService)
assert isinstance(service.repository, Repository)
assert isinstance(service.repository, ProductsRepository)
assert isinstance(service.repository.db_connection, DBConnection)
```

## Checking if a type is registered

To check if a type is registered in the container, use the `__contains__`
interface:

```python {linenums="1", hl_lines="11-12"}
from rodi import Container

class A: ...

class B: ...

container = Container()

container.add_transient(A)

assert A in container  # True
assert B not in container  # True
```

This can be useful for supporting alternative ways to register types. For
example, test code can register a mock type for a class, and the code under
test can check whether an interface is already registered in the container,
skipping the registration if it is.

The next page explains how to work with [async](./async.md).
