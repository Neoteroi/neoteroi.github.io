This page covers the following subjects:

- [X] Recommendations to work with types.
- [X] Support for collections.

## DI :heart: custom types

**Dependency Injection** loves custom types.
Consider the following example:

```python
class Example:
    def __init__(self, api_key: str):
        if not api_key:
            raise ValueError("API key is required")
        self.api_key = settings.api_key
```

There is a potential issue with the code above. Can you spot it?

The `Example` class depends on a `str`. We could register a `str` singleton in
our DI container, but it wouldn't make sense. Some other class might require a `str`
dependency, and we would be out of options to resolve then. All types that require a
simple type passed to their constructor are best configured using a _factory_ function.

We could do:

```python
def example_factory() -> Example:
    return Example(os.environ.get("API_KEY"))
```

## Support for collections

The next page explains how to deal with `async` code and classes that require
[asynchronous initialization](./async.md).
