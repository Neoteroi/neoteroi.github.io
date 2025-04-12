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

/// admonition | Protocols validation
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

Generic types are supported.

```python {linenums="1", hl_lines="1 6 9 29 34 40-41 44-45"}
from typing import Generic, TypeVar

from rodi import Container


T = TypeVar("T")


class LoggedVar(Generic[T]):
    def __init__(self, value: T, name: str):
        self.name = name
        self.value = value

    def set(self, new: T):
        self.log("Set " + repr(self.value))
        self.value = new

    def get(self) -> T:
        self.log("Get " + repr(self.value))
        return self.value

    def log(self, message: str):
        print(self.name, message)


container = Container()


class A(LoggedVar[int]):
    def __init__(self):
        super().__init__(10, "example")


class B(LoggedVar[str]):
    def __init__(self):
        super().__init__("Foo", "example")


class C:
    a: LoggedVar[int]
    b: LoggedVar[str]


container.add_scoped(LoggedVar[int], A)
container.add_scoped(LoggedVar[str], B)
container.add_scoped(C)

instance = container.resolve(C)

assert isinstance(instance.a, A)
assert isinstance(instance.b, B)
```

As described above, use the *most* abstract class as the key to resolve more
*concrete* types, in accordance with the Dependency Inversion Principle (DIP). Generics are the **most** abstract
type, so use them as keys like in the example above at lines _44-45_.

## Checking if a type is registered

To check if a type is registered in the container, use the `__contains__` interface:

```python {linenums="1", hl_lines="11-12"}
from rodi import Container

class A: ...

class B: ...

container = Container()

container.add_transient(A)

assert A in container  # True
assert B not in container  # True
```

This can be useful to support alternative ways to register types. For example, tests
code can register a mock type for a class, and the code under test can check if any
interface is already registered in the container, and skip the registration if it is.

The next page explains how to work with [types and collections](./types.md).
