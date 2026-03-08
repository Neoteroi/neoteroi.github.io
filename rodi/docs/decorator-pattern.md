This page describes how to use the [_decorator pattern_](https://en.wikipedia.org/wiki/Decorator_pattern) with Rodi's dependency injection container, available since version `2.1.0`.

- [X] What the decorator pattern is.
- [X] Basic usage with `container.decorate()`.
- [X] Decorators with additional dependencies.
- [X] Chaining multiple decorators.
- [X] Lifetime behaviour.
- [X] Class-property injection in decorators.

## What is the decorator pattern?

The [decorator pattern](https://en.wikipedia.org/wiki/Decorator_pattern) is a structural
design pattern that wraps an object with another object that shares the same interface.
The outer object — the _decorator_ — adds or modifies behaviour before or after
delegating to the inner object.

Common uses include:

- **Logging** — record calls transparently, without touching business logic.
- **Caching** — return cached results when available.
- **Retry / resilience** — retry failed calls automatically.
- **Authorisation** — gate access without changing the service.
- **Metrics / tracing** — instrument calls for observability.

Because both the original service and its decorators implement the same interface,
the rest of the application has no idea decorators exist.

## Basic usage

Use `container.decorate(base_type, decorator_type)` to wrap an already-registered type.

The decorator class must satisfy one rule: its `__init__` must have **at least one
parameter whose type annotation matches the registered base type** (or a supertype of
it). That parameter receives the inner service instance. Every other `__init__` parameter
is resolved from the container as usual.

```python {linenums="1", hl_lines="5 10 15 28-29"}
from abc import ABC, abstractmethod
from rodi import Container


class MessageSender(ABC):
    @abstractmethod
    def send(self, message: str) -> None: ...


class ConsoleSender(MessageSender):
    def send(self, message: str) -> None:
        print(f"[console] {message}")


class LoggingMessageSender(MessageSender):
    """Decorator: records every message before delegating to the inner sender."""

    def __init__(self, inner: MessageSender) -> None:
        self.inner = inner
        self.log: list[str] = []

    def send(self, message: str) -> None:
        self.log.append(message)
        self.inner.send(message)


container = Container()
container.add_transient(MessageSender, ConsoleSender)
container.decorate(MessageSender, LoggingMessageSender)

sender = container.resolve(MessageSender)

assert isinstance(sender, LoggingMessageSender)   # outer decorator
assert isinstance(sender.inner, ConsoleSender)     # inner service

sender.send("Hello!")
assert sender.log == ["Hello!"]
```

/// admonition | Order matters.
    type: tip

`decorate()` must be called **after** the base type is registered. An unregistered
base type raises `DecoratorRegistrationException` immediately.

///

## Decorators with additional dependencies

The decorator's `__init__` can declare any number of extra parameters alongside
the decoratee. Rodi resolves them from the container exactly as it would for any
other type.

```python {linenums="1", hl_lines="4 7 20-23 37-38"}
from rodi import Container


class MessageSender: ...


class ConsoleSender(MessageSender):
    def send(self, message: str) -> None:
        print(message)


class Logger:
    def __init__(self) -> None:
        self.entries: list[str] = []

    def log(self, text: str) -> None:
        self.entries.append(text)


class InstrumentedSender(MessageSender):
    def __init__(self, inner: MessageSender, logger: Logger) -> None:
        self.inner = inner
        self.logger = logger

    def send(self, message: str) -> None:
        self.logger.log(f"send({message!r})")
        self.inner.send(message)


container = Container()
container.add_transient(Logger)
container.add_transient(MessageSender, ConsoleSender)
container.decorate(MessageSender, InstrumentedSender)

sender = container.resolve(MessageSender)

assert isinstance(sender, InstrumentedSender)
assert isinstance(sender.logger, Logger)
sender.send("Hi")
assert sender.logger.entries == ["send('Hi')"]
```

## Chaining multiple decorators

Calling `decorate()` more than once for the same type **chains** the decorators.
Each call wraps the current registration, so the **last registered decorator is
the outermost one**.

```python {linenums="1", hl_lines="33-34"}
from rodi import Container


class Greeter:
    def greet(self, name: str) -> str: ...


class SimpleGreeter(Greeter):
    def greet(self, name: str) -> str:
        return f"Hello, {name}"


class LoggingGreeter(Greeter):
    def __init__(self, inner: Greeter) -> None:
        self.inner = inner
        self.calls: list[str] = []

    def greet(self, name: str) -> str:
        self.calls.append(name)
        return self.inner.greet(name)


class ExclamatoryGreeter(Greeter):
    def __init__(self, inner: Greeter) -> None:
        self.inner = inner

    def greet(self, name: str) -> str:
        return self.inner.greet(name) + "!"


container = Container()
container.add_transient(Greeter, SimpleGreeter)
container.decorate(Greeter, LoggingGreeter)      # wraps SimpleGreeter
container.decorate(Greeter, ExclamatoryGreeter)  # wraps LoggingGreeter

greeter = container.resolve(Greeter)

# ExclamatoryGreeter → LoggingGreeter → SimpleGreeter
assert isinstance(greeter, ExclamatoryGreeter)
assert isinstance(greeter.inner, LoggingGreeter)
assert isinstance(greeter.inner.inner, SimpleGreeter)

assert greeter.greet("World") == "Hello, World!"
```

## Lifetime behaviour

A decorator **inherits the lifetime of the service it wraps**. If the inner service
is a singleton, the whole decorated chain is a singleton; if it is scoped, the chain
is scoped; if transient, the chain is transient.

=== "Singleton"

    ```python {linenums="1", hl_lines=""}
    container = Container()
    container.add_singleton(MessageSender, ConsoleSender)
    container.decorate(MessageSender, LoggingMessageSender)

    provider = container.build_provider()

    a = provider.get(MessageSender)
    b = provider.get(MessageSender)
    assert a is b  # same instance every time
    ```

=== "Scoped"

    ```python {linenums="1", hl_lines=""}
    container = Container()
    container.add_scoped(MessageSender, ConsoleSender)
    container.decorate(MessageSender, LoggingMessageSender)

    provider = container.build_provider()

    with provider.create_scope() as scope:
        a = provider.get(MessageSender, scope)
        b = provider.get(MessageSender, scope)
        assert a is b  # same instance within the scope

    with provider.create_scope() as scope2:
        c = provider.get(MessageSender, scope2)
        assert c is not a  # new instance in a new scope
    ```

=== "Transient"

    ```python {linenums="1", hl_lines=""}
    container = Container()
    container.add_transient(MessageSender, ConsoleSender)
    container.decorate(MessageSender, LoggingMessageSender)

    provider = container.build_provider()

    a = provider.get(MessageSender)
    b = provider.get(MessageSender)
    assert a is not b  # fresh instance each time
    ```

## Class-property injection in decorators

Decorators support the same [mixed injection](./getting-started.md) as any other
registered type. If the decorator class has **class-level type annotations** in addition
to its `__init__` parameters, Rodi injects those properties via `setattr` after
construction — exactly as it does for regular services.

```python {linenums="1", hl_lines="19 21 37"}
from rodi import Container


class Greeter:
    def greet(self, name: str) -> str: ...


class SimpleGreeter(Greeter):
    def greet(self, name: str) -> str:
        return f"Hello, {name}"


class Logger:
    def __init__(self) -> None:
        self.entries: list[str] = []


class LoggingGreeter(Greeter):
    logger: Logger  # injected via setattr after __init__

    def __init__(self, inner: Greeter) -> None:
        self.inner = inner

    def greet(self, name: str) -> str:
        self.logger.log(f"greet({name!r})")
        return self.inner.greet(name)


container = Container()
container.add_transient(Greeter, SimpleGreeter)
container.add_transient(Logger)
container.decorate(Greeter, LoggingGreeter)

greeter = container.resolve(Greeter)

assert isinstance(greeter, LoggingGreeter)
assert isinstance(greeter.logger, Logger)  # injected as class property
```
