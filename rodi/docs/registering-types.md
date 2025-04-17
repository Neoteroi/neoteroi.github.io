This page dives into more details, covering the following subjects:

- [X] Types lifetime.
- [X] Options to register types.
- [X] Using factories.
- [X] Working with simple types.
- [X] Support for collections.
- [X] Working with generic types.
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

/// admonition | Container lifecycle.
    type: danger

If you modify the `Container` after the dependency tree has been created, for example
registering a new type after any type has been resolved, all created singletons are
discarded and will be recreated when requested again. Modifying the `Container` during
the lifetime of the application is an anti-pattern, and should be avoided. It also
forces the container to repeat code inspections, causing a performance fee.

To avoid exposing the mutable `container`, use the `container.build_provider()`
method, which returns an instance of `Services` that can only be used to
resolve types, without modifying the tree graph. The `Services` class still
offers a `set` method, which can only be used to add new singletons to the
set of types that can be instantiated.
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

/// details | Nested scopes.
    type: warning

Rodi was not designed having _nested_ scopes in mind. Scopes are designed to
identify a resolution call for a single event, such as DI resolution for a
single HTTP request.

Since version `2.0.7`, Rodi offers the possibility to specify the
`ActivationScope` class used by the container, when instantiating the
`Container` object. This class will be used when creating new scopes. Version
`2.0.7` also added an **experimental** class, `TrackingActivationScope` to
support nested scopes transparently, using `contextvars.ContextVar`.

```python {linenums="1" hl_lines="2 12 16 27"}
def test_nested_scope_1():
    container = Container(scope_cls=TrackingActivationScope)
    container.add_scoped(Ok)
    provider = container.build_provider()

    with provider.create_scope() as context_1:
        a = provider.get(Ok, context_1)

        with provider.create_scope() as context_2:
            b = provider.get(Ok, context_2)

        assert a is b


def test_nested_scope_2():
    container = Container(scope_cls=TrackingActivationScope)
    container.add_scoped(Ok)
    provider = container.build_provider()

    with provider.create_scope():
        with provider.create_scope() as context:
            a = provider.get(Ok, context)

        with provider.create_scope() as context:
            b = provider.get(Ok, context)

        assert a is not b
```

///

Note how the generics `Repository[Product]` and `Repository[Customer]` are both
configured to be resolved using `Repository` as concrete type. Instances of
`GenericAlias` are not considered as actual classes. The following wouldn't
work:

```python
container.add_scoped(Repository[Product])  # No. 💥
container.add_scoped(Repository[Customer])  # No. 💥
```

## Using factories

**add_transient_by_factory**, **add_singleton_by_factory**, and **add_scoped_by_factory**
accept a function that returns an instance of the type to register.

Valid function signatures include:

- `def factory():`
- `def factory(context: rodi.ActivationScope):`
- `def factory(context: rodi.ActivationScope, activating_type: type):`

The context is the current activation scope, and grants access to the set of
scoped services and to the `ServiceProvider` object under construction. The
`activating_type` is the type that is being activated and required resolving
the service. This can be useful in some scenarios, when the returned object
must vary depending on the type that required it.

```python {linenums="1", hl_lines="15-16"}
from rodi import ActivationScope, Container


class A: ...

class B:
    friend: A

class C: ...

container = Container()


def a_factory(context, activating_type) -> A:
    assert isinstance(context, ActivationScope)
    assert activating_type is B

    # You can obtain other types using `context.provider.get`
    # (if they can be resolved)
    c = context.provider.get(C)
    assert isinstance(c, C)

    return A()


container.add_transient_by_factory(a_factory)
container.add_transient(B)
container.add_transient(C)

b = container.resolve(B)
assert isinstance(b.friend, A)
```

## Working with simple types

**Dependency Injection** loves custom types. Consider the following example:

```python
class Example:
    def __init__(self, api_key: str):
        if not api_key:
            raise ValueError("API key is required")
        self.api_key = settings.api_key
```

The `Example` class depends on a `str`. We could register a `str` singleton in
our DI container, but it wouldn't make sense. Some other class might require a
`str` dependency, and we would be out of options to resolve them. All types
that require a simple type passed to their constructor are best configured
using a _factory_ function.

```python
def example_factory() -> Example:
    return Example(os.environ.get("API_KEY"))
```

In many cases, it is advisable to define custom types to group settings
consisting of simple types into dedicated classes.

For example:

```python {linenums="1", hl_lines="2-3 7"}
@dataclass
class SendGridClientSettings:
    api_key: str


class SendGridClient(EmailHandler):
    settings: SendGridClientSettings
    http_client: httpx.AsyncClient
```

This approach has the following benefits:

- A factory can be used to obtain the settings class.
- The more complex type can be resolved using less verbose methods that inspect
  its constructor or class properties.

## Support for collections

Rodi supports registering and resolving collections.

```python {linenums="1", hl_lines="11-12"}
from rodi import Container


class A: ...


class B:
    friends: list[A]


def friends_factory() -> list[A]:
    return [A(), A()]


container = Container()

container.add_transient_by_factory(friends_factory)
container.add_transient(B)

b = container.resolve(B)
print(b.friends)
assert isinstance(b.friends, list)
assert isinstance(b.friends[0], A)
assert isinstance(b.friends[1], A)
```

Other containers such as `dict`, `set`, `Iterable`, `Mapping`, `Sequence`,
`Tuple` are also supported.

## The Services class

The `Container` class in Rodi can be used to register and resolve types, and it
is mutable (new types can be registered at any time). This design decision was
driven by the desire to keep the code API as simple as possible, and to enable
the possibility to replace the Rodi's container with alternative
implementations of dependency injection.

Although the container is mutable, it is generally recommended to use it in the
following way:

- Register all types in the container during application startup.
- Resolve types at runtime without registering new ones.

It can be undesirable to expose the mutable `Container` to the application
code, as it can lead to unexpected behavior. For this reason, the `Container`
class provides a method called `build_provider`, which returns a read-only
interface that can be used to resolve types, but not to register new ones
(with the exception of the `set` method, which allows adding new singletons
without altering the existing dependency tree).

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

Rodi defines a protocol for the `Container` class, named `ContainerProtocol`.
This protocol defines a generic interface of the container, which includes
methods for registering and resolving types, as well as checking if a type is
configured in the container.

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
        Returns a value indicating whether a given type is configured in this
        container.
        """
```

Since some features, like _Service Lifetime_ are specific to Rodi (some alternative
implementations only support _transient_ and _singleton_ lifetimes), the protocol does
not define methods for registering types with different lifetimes. The protocol only
defines unopinionated methods to `register` and `resolve` types, and to check if a type
is configured.

/// admonition | Interoperability.
    type: tip

If you author code that relies on a Dependency Injection container and you want to
support different implementations, you would need to decide on a common interface, or
[_Protocol_](https://peps.python.org/pep-0544/), required by your code. The
`ContainerProtocol` interface was originally thought for this purpose.
///

## Next steps

All examples on this page show how to register and resolve _concrete_ classes.
The next page describes how to apply the [_Dependency Inversion Principle_](./dependency-inversion.md),
how to work with _abstract_ classes, protocols, and generics.
