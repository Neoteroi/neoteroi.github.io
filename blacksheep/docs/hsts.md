The HTTP Strict-Transport-Security response header (often abbreviated as HSTS)
is a standard feature used to instruct clients that a site should only be
accessed using HTTPS, and any attempt to access it using HTTP should be
converted automatically to HTTPS.

BlackSheep offers a middleware to configure the HTTP Strict-Transport-Security
response header globally. This page explains how to use the built-in middleware
to enforce HSTS on a web application.

## Enabling HSTS

```python
from blacksheep import Application
from blacksheep.server.env import is_development
from blacksheep.server.security.hsts import HSTSMiddleware

app = Application()


if not is_development():
    app.middlewares.append(HSTSMiddleware())
```

!!! tip "Considerations for local development"
    It is generally undesirable to enable `HSTS` during local development,
    since browsers get instructed to require `HTTPS` for all traffic on
    `localhost`. This is why the example above configures the middleware only
    if the application is not running in development mode.
    See [_Defining application environment_](/blacksheep/settings/#defining-application-environment)
    for more information.

## Options

| Option             | Type   | Description                                                                   |
| ------------------ | ------ | ----------------------------------------------------------------------------- |
| max_age            | `int`  | Control the `max-age` directive of the HSTS header (default 31536000)         |
| include_subdomains | `bool` | Control the `include-subdomains` directive of the HSTS header (default false) |

## For more information
For more information on HTTP Strict Transport Security, it is recommended to
refer to the [developer.mozilla.org documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security).
