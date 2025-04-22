The HTTP Strict-Transport-Security (HSTS) response header is a standard feature
that instructs clients to access a site exclusively using HTTPS. Any attempt to
access the site via HTTP is automatically redirected to HTTPS.

BlackSheep provides middleware to globally configure the HTTP
Strict-Transport-Security (HSTS) response header. This page explains how to use
the built-in middleware to enforce HSTS in a web application.

## Enabling HSTS

```python
from blacksheep import Application
from blacksheep.server.env import is_development
from blacksheep.server.security.hsts import HSTSMiddleware

app = Application()


if not is_development():
    app.middlewares.append(HSTSMiddleware())
```

/// admonition | Considerations for local development.
    type: tip

Enabling `HSTS` during local development is generally not recommended, as it
instructs browsers to require `HTTPS` for all traffic on `localhost`. For this
reason, the example above configures the middleware only when the application
is not running in development mode. Refer to [_Defining application environment_](settings.md#defining-application-environment)
for more information.

///

## Options

| Option             | Type   | Description                                                                   |
| ------------------ | ------ | ----------------------------------------------------------------------------- |
| max_age            | `int`  | Control the `max-age` directive of the HSTS header (default 31536000)         |
| include_subdomains | `bool` | Control the `include-subdomains` directive of the HSTS header (default false) |

## For more information

For more information on HTTP Strict Transport Security, refer to the
[developer.mozilla.org
documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security).
