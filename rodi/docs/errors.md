This page describes errors and custom exceptions raised by Rodi.

## Errors

| Name                             | Description                                                                                                                                                                   |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CannotResolveTypeException`     | This error is raised when a type cannot be resolved because it was not registered in the container.                                                                           |
| `CircularDependencyException`    | This error is raised when a circular dependency is detected and cannot be resolved.                                                                                           |
| `FactoryMissingContextException` | This error is raised when a factory function does not have `_locals`. This generally happens only if classes are defined inside functions and use locals (not a common case). |
| `MissingTypeException`           | This error is raised when a factory function does not specify its return type annotation, and the user does not specify the type it returns.                                  |
| `OverridingServiceException`     | This error is raised when the user tries to override a type that is already registered in the container.                                                                      |

## Cannot resolve type

```python {linenums="1", hl_lines="11"}
from rodi import Container


class A: ...

class B:
    dependency: A


container = Container()
container.register(B)

container.resolve(B)  # <-- raises exception 💥
```

`rodi.CannotResolveParameterException: Unable to resolve parameter 'dependency' when resolving 'B'`

All dependencies must be explicitly registered in the container. To resolve the
error, register the missing type:

```python {linenums="1", hl_lines="11-12"}
from rodi import Container


class A: ...

class B:
    dependency: A


container = Container()
container.register(A)
container.register(B)

container.resolve(B)
```

## The chicken and egg problem :chicken: :egg:

The following classes have a circular dependency:

```python
class Chicken:
    egg: "Egg"


class Egg:
    chicken: Chicken
```

If we try to have Rodi resolve them automatically, we get an error:

```python  {linenums="1", hl_lines="4-5 8-9 17"}
from rodi import Container


class Chicken:
    egg: "Egg"


class Egg:
    chicken: Chicken


container = Container()
container.register(Chicken)
container.register(Egg)

# The following line raises an exception:
chicken = container.resolve(Chicken)  # 💥
```

The raised error is:

`    raise CircularDependencyException(chain[0], concrete_type)
rodi.CircularDependencyException: A circular dependency was detected for the service of type 'Chicken' for 'Egg'`.

Rodi cannot infer automatically which type should be instantiated first:
_Chicken_ or _Egg_?
