This page describes how to apply the _Dependency Inversion Principle_, working with
_abstract_ classes and protocols.

- [X] Working with interfaces.
- [X] Using abstract classes and protocols.

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

## Using factories

When using factories to define how types are created, specify the interface by using the
factory's return type annotation.

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

**add_transient_by_factory**, **add_singleton_by_factory**, and **add_scoped_by_factory**
accept a function that returns an instance of the type to register.

Valid function signatures include:

- `def factory():`
- `def factory(context: rodi.ActivationScope):`
- `def factory(context: rodi.ActivationScope, activating_type: type):`

The context is the current activation scope, and grants access to the set of scoped
services and to the `ServiceProvider` object under construction.
The `activating_type` is the type that is being activated and required resolving the
service. This can be useful in some scenarios, when the returned object must vary
depending on the type that required it.

```python {linenums="1", hl_lines="13-14 18"}
from rodi import ActivationScope, Container


class C: ...


class A: ...


class B:
    friend: A


container = Container()


def factory(context, activating_type) -> A:
    assert isinstance(context, ActivationScope)
    assert activating_type is B

    # You can obtain other types using `context.provider.get`
    # (if they can be resolved)
    c = context.provider.get(C)
    assert isinstance(c, C)

    return A()


container.add_transient(C)
container.add_transient_by_factory(factory)
container.add_transient(B)

b = container.resolve(B)
assert isinstance(b.friend, A)
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
