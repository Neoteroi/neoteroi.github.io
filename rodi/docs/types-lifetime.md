This page dives into more details, covering the following subjects:

- [X] Types lifetime.
- [X] Options to register types.
- [X] The `Services` class.

## Types lifetime

Rodi supports three kinds of lifetimes:

- **Singleton** lifetime, for types that must be created only once per container.
- **Transient** lifetime, for types that must be created every time they are
  requested.
- **Scoped** lifetime, for types that must be created once per resolution scope
  (e.g. once per HTTP web request, once per user interaction).

The next paragraphs describe each type in detail.

### Transient lifetime

Transient lifetime is the most common kind for types registered in Rodi. It means
that a new instance of a class will be created every time it is requested.

```python
from rodi import Container

class A: ...

container = Container()

container.add_transient(A)

a1 = container.resolve(A)  # a1 is a new instance of A
a2 = container.resolve(A)  # a2 is another new instance of A
a1 is not a2  # True
```

The `Container` class offers two methods to register types with transient lifetime:

- **add_transient** to register a _transient_ type by class.
- **add_transient_by_factory** to register a _transient_ type by factory function.

### Singleton lifetime

The singleton lifetime is used for types that should be instantiated only once per
container's dependency graph.

```python
from rodi import Container

class A: ...

container = Container()

container.add_singleton(A)

a1 = container.resolve(A)  # a1 is a new instance of A
a2 = container.resolve(A)  # a2 is the same instance of A
a1 is a2  # True
```

The `Container` class offers three methods to register types with singleton lifetime:

- **add_instance** to register a _singleton_ using an instance.
- **add_singleton** to register a _singleton_ type by class.
- **add_singleton_by_factory** to register a _singleton_ type by factory function.

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

    ```python {linenums="1", hl_lines="9-10"}
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
forces the container to repeat code inspections, reducing performance.

To avoid exposing the modifiable `container`, use the `container.build_provider()`
method, which returns an instance of `Services` that can only be used to resolve types,
without modifying the container.
///

### Container lifetime

The primary use of Rodi is to create a single instance of the `Container` class,
configure it at application startup, and avoid modifying during the lifetime of the
application.

However, it is still possible to use multiple instances of the `Container` class and to
modify the configuration of a container even after the depedency tree has been created.
This is to be considered an anti pattern, and has the following drawbacks:

- If the `Container` is modified after a type has been resolved, the dependency
