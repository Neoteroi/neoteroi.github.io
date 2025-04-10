This page dives into more details, covering the following subjects:

- [X] Types lifetime.
- [X] Options to register types.
- [X] The `Services` class.
- [X] The `ContainerProtocol`.

## Types lifetime

Rodi supports three kinds of lifetimes:

- **Singleton** lifetime, for types that must be created only once per container.
- **Transient** lifetime, for types that must be created every time they are
  requested.
- **Scoped** lifetime, for types that must be created once per resolution scope
  (e.g. once per HTTP web request, once per user interaction).

The next paragraphs describe each type in detail.

### Transient lifetime

Transient lifetime is the most common kind for types registered in Rodi. It means that a
new instance of a class will be created every time it is requested. The `Container`
class offers three methods to register types with transient lifetime:

- **register** to register a _transient_ type by class.
- **add_transient** to register a _transient_ type by class.
- **add_transient_by_factory** to register a _transient_ type by factory function.

=== "register"

    ```python {linenums="1", hl_lines="8"}
    from rodi import Container

    class A:
        ...

    container = Container()

    container.register(A)

    a1 = container.resolve(A)
    a2 = container.resolve(A)
    assert isinstance(a1, A)
    assert isinstance(a2, A)
    assert a1 is not a2
    ```

=== "add_transient"

    ```python {linenums="1", hl_lines="8"}
    from rodi import Container

    class A:
        ...

    container = Container()

    container.add_transient(A)

    a1 = container.resolve(A)
    a2 = container.resolve(A)
    assert isinstance(a1, A)
    assert isinstance(a2, A)
    assert a1 is not a2
    ```

=== "add_transient_by_factory"

    ```python {linenums="1", hl_lines="6-7 11"}
    from rodi import Container

    class A:
        ...

    def a_factory() -> A:
        return A()

    container = Container()

    container.add_transient_by_factory(a_factory)

    a1 = container.resolve(A)
    a2 = container.resolve(A)
    assert isinstance(a1, A)
    assert isinstance(a2, A)
    assert a1 is not a2
    ```

### Singleton lifetime

The singleton lifetime is used for types that should be instantiated only once per
container's dependency graph. The `Container` class offers three methods to register
types with singleton lifetime:

- **register** to register a _singleton_ type by class and instance.
- **add_instance** to register a _singleton_ using an instance.
- **add_singleton** to register a _singleton_ type by class.
- **add_singleton_by_factory** to register a _singleton_ type by factory function.

=== "register"

    ```python {linenums="1", hl_lines="7"}
    from rodi import Container

    class A: ...

    container = Container()

    container.register(A, instance=A())

    a1 = container.resolve(A)
    a2 = container.resolve(A)
    assert isinstance(a1, A)
    assert isinstance(a2, A)
    assert a1 is not a2
    ```

=== "add_instance"

    ```python {linenums="1", hl_lines="9"}
    from rodi import Container

    class Cat:
        def __init__(self, name: str):
            self.name = name

    container = Container()

    container.add_instance(Cat("Tom"))

    example = container.resolve(Cat)
    assert isinstance(example, Cat)
    assert example.name == "Tom"
    ```

=== "add_singleton"

    ```python {linenums="1", hl_lines="8"}
    from rodi import Container

    class Cat:
      pass

    container = Container()

    container.add_singleton(Cat)

    example = container.resolve(Cat)
    assert isinstance(example, Cat)
    ```

=== "add_singleton_by_factory"

    ```python {linenums="1", hl_lines="9-10 12"}
    from rodi import Container

    class Cat:
        def __init__(self, name: str):
            self.name = name

    container = Container()

    def cat_factory() -> Cat:
        return Cat("Tom")

    container.add_singleton_by_factory(Cat)

    example = container.resolve(Cat)
    assert isinstance(example, Cat)
    assert example.name == "Tom"
    ```

/// admonition | Container lifecycle
    type: danger

If you modify the `Container` after the dependency tree has been created, for example
registering a new type after any type has been resolved, all created singletons are
discarded and will be recreated when requested again. Modifying the `Container` during
the lifetime of the application is an anti-pattern, and should be avoided. It also
forces the container to repeat code inspections, causing a performance fee.

To avoid exposing the mutable `container`, use the `container.build_provider()`
method, which returns an instance of `Services` that can only be used to resolve types,
without modifying the container.
///

### Scoped lifetime

The scoped lifetime is used for types that should be instantiated only once per
container's resolution call. The `Container` class offers two methods to register types
with scoped lifetime:

- **add_scoped** to register a _scoped_ type by class.
- **add_scoped_by_factory** to register a _scoped_ type by factory function.

=== "add_scoped"

    ```python {linenums="1", hl_lines="7 10 15 19 23 25 29 31"}
    from rodi import Container

    class A:
        ...

    class B:
        context: A

    class C:
        context: A
        dependency: B

    container = Container()

    container.add_scoped(A)
    container.add_scoped(B)
    container.add_scoped(C)

    c1 = container.resolve(C)  # A is created only once for both B and C
    assert isinstance(c1, C)
    assert isinstance(c1.dependency, B)
    assert isinstance(c1.context, A)
    assert c1.context is c1.dependency.context

    c2 = container.resolve(C)
    assert isinstance(c2, C)
    assert isinstance(c2.dependency, B)
    assert isinstance(c2.context, A)
    assert c2.context is c2.dependency.context

    assert c1.context is not c2.context
    ```

=== "add_scoped_by_factory"

    ```python {linenums="1", hl_lines="16-17 22"}
    from rodi import Container


    class A: ...


    class B:
        context: A


    class C:
        context: A
        dependency: B


    def a_factory() -> A:
        return A()


    container = Container()

    container.add_scoped_by_factory(a_factory)
    container.add_scoped(B)
    container.add_scoped(C)

    c1 = container.resolve(C)  # A is created only once for both B and C
    assert isinstance(c1, C)
    assert isinstance(c1.dependency, B)
    assert isinstance(c1.context, A)
    assert c1.context is c1.dependency.context

    c2 = container.resolve(C)
    assert isinstance(c2, C)
    assert isinstance(c2.dependency, B)
    assert isinstance(c2.context, A)
    assert c2.context is c2.dependency.context

    assert c1.context is not c2.context
    ```

## The Services class

The `Container` class in Rodi can be used to register and resolve types, and it is
mutable (new types can be registered at any time). This design decision was driven by
the desire to keep the code API as simple as possible, and to enable the possibility to
replace the Rodi's container with alternative implementations of dependency injection.

Although the container is mutable, it is generally recommended to use it in the
following way:

- Register all types in the container during application startup.
- Resolve types at runtime without registering new ones.

It can be undesirable to expose the mutable `Container` to the application code, as it
can lead to unexpected behavior. For this reason, the `Container` class provides a
method called `build_provider`, which returns a read-only interface that can be used to
resolve types, but not to register new ones.

```python
from rodi import Container


class A: ...


container = Container()

container.add_transient(A)

provider = container.build_provider()

a1 = provider.get(A)
a2 = provider.get(A)
assert isinstance(a1, A)
assert isinstance(a2, A)
assert a1 is not a2
```

### The ContainerProtocol

Rodi defines a protocol for the `Container` class, named `ContainerProtocol`. This
protocol defines a generic interface of the container, which includes methods for
registering and resolving types, as well as checking if a type is configured in the
container.

The purpose of this protocol is to support replacing Rodi with alternative
implementations of dependency injection in code that requires basic container
functionality. The protocol is defined as follows:

```python
class ContainerProtocol(Protocol):
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

Since some features, like _Service Lifetime_ are specific to Rodi (some alternative
implementations only support _transient_ and _singleton_ lifetimes), the protocol does
not define methods for registering types with different lifetimes. The protocol only
defines unopinionated methods to `register` and `resolve` types, and to check if a type
is configured.

/// admonition | Interoperability
    type: tip

If you author code that relies on a Dependency Injection container and you want to
support different implementations, you would need to decide on a common interface, or
[_Protocol_](https://peps.python.org/pep-0544/), required by your code. The
`ContainerProtocol` interface was originally thought for this purpose.
///

## Next steps

All examples on this page show how to register and resolve _concrete_ classes.
The next page describes how to apply the [_Dependency Inversion Principle_](./dependency-inversion.md),
and how to work with _abstract_ classes and protocols.
