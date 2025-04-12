This page describes how to work with Rodi and context managers.

## How Rodi handles context managers

When a class implements the context manager protocol (`__enter__`, `__exit__`),
Rodi instantiates the class but does **not** enter nor exit the instance
automatically.

```python  {linenums="1", hl_lines="4 10 15 25-26 41"}
from rodi import Container


class A:
    def __init__(self) -> None:
        print("A created")
        self.initialized = False
        self.disposed = False

    def __enter__(self) -> "A":
        print("A initialized")
        self.initialized = True
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.disposed = True
        print("A destroyed")


class B:
    def __init__(self, dependency: A) -> None:
        self.dependency = dependency

    def do_work(self):
        with self.dependency:
            print("Do work")


container = Container()

container.register(A)
container.register(B)

b = container.resolve(B)

# b.dependency is instantiated and provided as is, it is not entered
# automatically
assert b.dependency.initialized is False
assert b.dependency.disposed is False

b.do_work()
assert b.dependency.initialized is True
assert b.dependency.disposed is True
```

/// admonition | Rodi does not enter and exit contexts.
    type: into

There is no way to unambiguously know the intentions of the developer:
should a context be entered automatically and disposed automatically?
///

## Async context managers

As described above for context managers, Rodi does not handle async context
managers in any special way either.

```python  {linenums="1", hl_lines="6 12 17 26-27 41"}
import asyncio

from rodi import Container


class A:
    def __init__(self) -> None:
        print("A created")
        self.initialized = False
        self.disposed = False

    async def __aenter__(self) -> "A":
        print("A initialized")
        self.initialized = True
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb) -> None:
        self.disposed = True
        print("A destroyed")


class B:
    def __init__(self, dependency: A) -> None:
        self.dependency = dependency

    async def do_work(self):
        async with self.dependency:
            print("Do work")


container = Container()

container.register(A)
container.register(B)

b = container.resolve(B)
assert b.dependency.initialized is False
assert b.dependency.disposed is False


asyncio.run(b.do_work())
assert b.dependency.initialized is True
assert b.dependency.disposed is True
```

The next page describes support for [_Union types_](./union-types.md) in Rodi.
