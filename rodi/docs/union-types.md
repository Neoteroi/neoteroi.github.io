This page describes support for _Union_ types in Rodi.

- [X] Optional dependencies.
- [X] Union types dependencies.

## Optional dependencies

It is uncommon for types resolved with dependency injection to have optional
dependencies, however this scenario is supported by Rodi.

```python {linenums="1", hl_lines="8 12 15"}
from rodi import Container


class A: ...


class B:
    dependency: A | None


container = Container()
container.register(A | None, A)
container.register(B)

b = container.resolve(B)
assert isinstance(b.dependency, A)
```

/// admonition | Optional types keys.
    type: warning

Beware that if you specify a _T_ dependency as _optional_, the _key_ type used to
resolve the dependency becomes the _T | None_ and it is not just _T_.
///

A factory function can be used to define logic that determines how the
dependency must be resolved:

```python {linenums="1", hl_lines="8 12 15"}
from rodi import Container


class A: ...


class B:
    dependency: A | None


def a_factory() -> A | None:
    # TODO: implement logic that determines what to return
    return None


container = Container()
container.add_transient_by_factory(a_factory)
container.register(B)

b = container.resolve(B)
assert b.dependency is None
```

## Union dependencies

Union types are also supported:

```python {linenums="1", hl_lines="11 14 20 23-24"}
from rodi import Container


class A: ...


class B: ...


class C:
    dependency: A | B


def ab_factory() -> A | B:
    # TODO: implement logic that determines what to return
    return A()


container = Container()
container.add_transient_by_factory(ab_factory)
container.register(C)

c = container.resolve(C)
assert isinstance(c.dependency, A)
```

/// admonition | Union types keys.
    type: warning

Beware that if you specify a union dependency such as _T | U_ the _key_ type
used to resolve the dependency is _T | U_. Trying to use _T_ or _U_
singularly causes a _`CannotResolveTypeException`_.
///


---

The next page provides an overview of [errors](./errors.md) raised by Rodi.
