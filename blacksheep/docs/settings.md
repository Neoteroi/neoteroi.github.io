# Settings

While _most_ settings are described in sections that are dedicated to other
topics, this page describes other settings that can be used in BlackSheep.
This page describes:

- [X] features to describe the environment of a BlackSheep web application.
- [X] features to control JSON serialization and deserialization

## Environmental variables

| Name                     | Category | Description                                                                                                                                                                                                                                                                                                 |
| ------------------------ | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| APP_ENV                  | Settings | This environment variable is read to determine the environment of the application. For more information, refer to [_Defining application environment_](/blacksheep/settings/#defining-application-environment).                                                                                             |
| APP_DEFAULT_ROUTER       | Settings | Allows disabling the use of the default router exposed by BlackSheep. To disable the default router: `APP_DEFAULT_ROUTER=0`.                                                                                                                                                                                |
| APP_SIGNAL_HANDLER       | Settings | Allows enabling a callback to the `{signal.SIGINT, signal.SIGTERM}` signals to detect when the application process is stopping. Information is used in `blacksheep.server.process.is_stopping()` and is useful when handling long-lasting connections. See _[Server-Sent Events](./server-sent-events.md)_. |
| APP_JINJA_EXTENSION      | Settings | Allows configuring the file extension used to work with Jinja templates. By default it is `.jinja`.                                                                                                                                                                                                         |
| APP_JINJA_PACKAGE_NAME   | Settings | Allows configuring the package name used by the default Jinja templates loader. By default it is `app` (as by default views are loaded from `app/views`.                                                                                                                                                    |
| APP_JINJA_PACKAGE_PATH   | Settings | Allows configuring the path used by the default Jinja templates loader. By default it is `views` (as by default views are loaded from `app/views`.                                                                                                                                                          |
| APP_JINJA_DEBUG          | Settings | Allows enabling Jinja debug mode, setting this env variable to a truthy value.                                                                                                                                                                                                                              |
| APP_JINJA_ENABLE_ASYNC   | Settings | Allows enabling Jinja async mode, setting this env variable to a truthy value.                                                                                                                                                                                                                              |
| APP_SHOW_ERROR_DETAILS   | Settings | If "1" or "true", configures the application to display web pages with error details in case of HTTP 500 Internal Server Error.                                                                                                                                                                             |
| APP_MOUNT_AUTO_EVENTS    | Settings | If "1" or "true", automatically binds lifecycle events of mounted apps between children and parents BlackSheep applications.                                                                                                                                                                                |
| APP_ROUTE_PREFIX         | Settings | Allows configuring a global prefix for all routes handled by the application. For more information, refer to: [Behind proxies](/blacksheep/behind-proxies/).                                                                                                                                                |
| APP_SECRET_<i>i</i>      | Secrets  | Allows configuring the secrets used by the application to protect data.                                                                                                                                                                                                                                     |
| BLACKSHEEP_SECRET_PREFIX | Secrets  | Allows specifying the prefix of environment variables used to configure application secrets, defaults to "APP_SECRET" if not specified.                                                                                                                                                                     |

## Defining application environment

BlackSheep implements a strategy to configure the environment of the application.
This configuration is useful to support enabling certain features depending on
the environment. For example:

- HTTP Strict Transport Security can be disabled for local development.
- Displaying error details can be enabled only when developing locally.
- When developing locally, application settings can be read from the user's
  folder.

The module `blacksheep.server.env` offers two functions that can be used to
control behavior depending on the app environment:

| Function         | True if `APP_ENV` is...          | Description                                                                                  |
| ---------------- | -------------------------------- | -------------------------------------------------------------------------------------------- |
| `is_development` | "local", "dev", or "development" | Returns a value indicating whether the application is running for a development environment. |
| `is_production`  | `None`, "prod", or "production"  | Returns a value indicating whether the application is running for a production environment.  |

The two functions read the environment variable `APP_ENV`. If `APP_ENV` is not
specified, the application defaults to production.

In the following example, the error details page displayed for unhandled
exceptions is enabled only for development, while [HTTP Strict Transport Security](/blacksheep/hsts/)
is only enabled for all other environments.

```python
from blacksheep import Application
from blacksheep.server.env import is_development
from blacksheep.server.security.hsts import HSTSMiddleware

app = Application()


if is_development():
    app.show_error_details = True
else:
    app.middlewares.append(HSTSMiddleware())
```

## Configuring JSON settings

BlackSheep supports configuring the functions that are used for JSON
serialization and deserialization in the web framework.

By default, the built-in `json` module is used for serializing and
deserializing objects, but this can be changed in the way illustrated below.

```python
from blacksheep.settings.json import json_settings


def custom_loads(value):
    """
    This function is responsible for parsing JSON into instances of objects.
    """


def custom_dumps(value):
    """
    This function is responsible for creating JSON representations of objects.
    """


json_settings.use(
    loads=custom_loads,
    dumps=custom_dumps,
)
```

!!! info
    BlackSheep uses by default a friendlier handling of `json.dumps`
    that supports serialization of common objects such as `UUID`, `date`,
    `datetime`, `bytes`, `@dataclass`, `pydantic` models, etc.

### Example: using orjson

To use [`orjson`](https://github.com/ijl/orjson) for JSON serialization and
deserialization with the built-in [`responses`](responses.md) and
`JSONContent` class, it can be configured this way:

```python
import orjson

from blacksheep.settings.json import json_settings


def serialize(value) -> str:
    return orjson.dumps(value).decode("utf8")


json_settings.use(
    loads=orjson.loads,
    dumps=serialize,
)

```

**Note:** the `decode("utf8")` call is required when configuring `orjson` for
the built-in `responses` functions and the `JSONContent` class. This is because
`orjson.dumps` function returns `bytes` instead of `str`, and this is something
specific to `orjson` implementation, different than the behavior of the
built-in `json` package and other libraries like `rapidjson`, `UltraJSON`, and
`fast-json`. The API implemented in `blacksheep` expects a JSON serialize
function that returns a `str` like in the built-in package.

For users using `orjson` who want to achieve the best performance and avoid the
fee of the superfluous `decode -> encode` passage, it is recommended to:

* not use the built-in `responses` functions and the built-in `JSONContent`
  class
* use a custom-defined function for JSON responses like the following example:

```python
def my_json(data: Any, status: int = 200) -> Response:
    """
    Returns a response with application/json content,
    and given status (default HTTP 200 OK).
    """
    return Response(
        status,
        None,
        Content(
            b"application/json",
            orjson.dumps(data),
        ),
    )
```

### Example: applying transformations during JSON operations

The example below illustrates how to apply transformations to objects while
they are serialized and deserialized. Beware that the example only illustrates
this possibility, it doesn't handle objects inside lists, `@dataclass`, or
`pydantic` models!

```python
import json
from typing import Any

from blacksheep.settings.json import json_settings
from essentials.json import dumps


def default_json_dumps(obj):
    return dumps(obj, separators=(",", ":"))


def custom_loads(value: str) -> Any:
    # example: applies a transformation when deserializing an object from JSON
    # this can be used for example to change property names upon deserialization

    obj = json.loads(value)

    if isinstance(obj, dict) and "@" in obj:
        obj["modified_key"] = obj["@"]
        del obj["@"]

    return obj


def custom_dumps(value: Any) -> str:
    # example: applies a transformation when serializing an object into JSON
    # this can be used for example to change property names upon serialization

    if isinstance(value, dict) and "@" in value:
        value["modified_key"] = value["@"]
        del value["@"]

    return default_json_dumps(value)


json_settings.use(
    loads=custom_loads,
    dumps=custom_dumps,
)
```

## Encodings settings

Starting from version `2.4.0`, the framework provides settings to control how
`UnicodeDecodeError` exceptions are handled when parsing request bodies.

By default the framework raises an exception when the client sends a payload
specifying the wrong encoding in the `Content-Type` request header, or when
the client sends a payload that is not `UTF-8` encoded and without specifying
the charset encoding.

To customize the handling of `UnicodeDecodeError` and implement possible
fallbacks, import the `Decoder` class from the `blacksheep.settings.encodings`
namespace and create your own implementation. Subclasses of this class define a
strategy for decoding bytes into strings when a `UnicodeDecodeError` occurs
during standard decoding. You must implement the `decode` method, which
receives the bytes to decode and the original `UnicodeDecodeError`.

```python
from blacksheep.settings.encodings import Decoder, encodings_settings


class MyDecoder(Decoder):
    """Implements the Decoder interface."""
    def decode(self, value: bytes, decode_error: UnicodeDecodeError) -> str: ...


encodings_settings.use(MyDecoder())
```
