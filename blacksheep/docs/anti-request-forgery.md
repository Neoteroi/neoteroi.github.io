# Preventing Cross-Site Request Forgery (XSRF/CSRF)

Cross-site request forgery, also known as XSRF or CSRF, is a kind of attack that
exploits situations in which browsers automatically include credentials in web
requests.

Examples of such situations are:

- Cookies are automatically included in web requests, so if an application uses
  cookie-based authentication, credentials are sent automatically
- After a user signs in with Basic or Digest authentication, the browser
  automatically sends the credentials until the session ends

If a web application uses cookie-based authentication or other features that
cause credentials to be automatically included in web requests, it requires
anti-forgery measures.

BlackSheep implements built-in support for anti-request-forgery validation, this
page describes how to use the built-in solution.

!!! tip
    Applications that store access tokens (for example JWTs) in the HTML5
    storage and include them in `Authorization: Bearer {...}` headers, are not
    vulnerable to CSRF and do not require anti-forgery measures.

## How to use the built-in anti-forgery validation

To enable anti-forgery validation, use the module `blacksheep.server.csrf`:

```python
from blacksheep import Application
from blacksheep.server.csrf import use_anti_forgery


app = Application(show_error_details=True)

use_anti_forgery(app)
```

The call to `use_anti_forgery(app)` configures a middleware that can issue and
validate anti-forgery tokens, and extensions for Jinja2 templates to render
anti-forgery tokens in HTML templates. It is important to configure templating
before anti-forgery because the latter configures the extensions on the Jinja2
environment.

Consider an example having this folder structure:

```
.
├── app
│   ├── __init__.py
│   └── views
│       └── index.jinja
└── server.py
```

Where `server.py` contains the following code:

```python
from blacksheep import Application, FromForm, get, post, view
from blacksheep.server.csrf import use_anti_forgery


app = Application(show_error_details=True)

use_anti_forgery(app)


@get("/")
def home(request):
    return view("index", {}, request=request)


class CreateUserInput:
    def __init__(self, username: str, **kwargs):
        self.username = username


@post("/user")
async def create_user(data: FromForm[CreateUserInput]):
    """Calls to this endpoint require an anti-forgery token."""
    return {"example": True, "username": data.value.username}
```

And `index.jinja` contains the following template:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Example</title>
</head>
<body>
    <form action="/user" method="post">
        {% af_input %}
        <input type="text" name="username" />
        <input type="submit" value="Submit" />
    </form>
</body>
</html>
```

The `{% af_input %}` custom tag is used to render an HTML input element containing an
anti-forgery token. The built-in solution uses the Double-Token strategy: when
an anti-forgery token is required to render HTML for a response, a corresponding
HTTP-only cookie is configured for the response. The value of the cookie and the
control parameter are matched in following requests for validation. Contextually,
response headers are also set to protect the HTML view against click-jacking and to
forbid iframes.

!!! tip "Alternative tags"
    In alternative to `{% af_input %}`, it is possible to use the tag
    `{% csrf_input %}` (like Django). However, `af_input` is recommended since
    the objective of the tag is to obtain an input element containing an
    anti-forgery token, not to achieve Cross-Site Request Forgery!

An example of a rendered view looks like the following:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Example</title>
</head>
<body>
    <form action="/user" method="post">
        <input type="hidden" name="__RequestVerificationToken" value="IlY2ejJ2MmQyWkZoUVo0ekxLdE9WVU9wQzhtR0dKbDNrdm1KVlc2SGwi.kAXPtBV3gFePzQQXRd0cO9fWOt0" />
        <input type="text" name="username" />
        <input type="submit" value="Submit" />
    </form>
</body>
</html>
```

Validation is applied by default to all `DELETE PATCH POST PUT` web requests.
Requests using other methods are not validated as they are not supposed to
change the state and should execute read-only operations.

!!! danger "Important note about token generation"
    Tokens are signed using symmetric encryption. For your production
    environments, configure application secrets using environment variables
    as described in [data protection](../dataprotection/).

## How to send the anti-forgery token

The anti-forgery token can be sent to the server in one of these ways:

| Location       | Parameter Name               |
| -------------- | ---------------------------- |
| Form parameter | `__RequestVerificationToken` |
| Header         | `RequestVerificationToken`   |

To use custom parameter names, refer to the `AntiForgeryHandler` class in
`blacksheep.server.csrf`.

## Example using Controllers

```
.
├── app
│   ├── __init__.py
│   └── views
│       └── home
│           └── index.jinja
└── server.py
```

`server.py`

```python
from blacksheep import Application, FromForm
from blacksheep.server.controllers import Controller, get, post
from blacksheep.server.csrf import use_anti_forgery

app = Application(show_error_details=True)

use_anti_forgery(app)


class CreateUserInput:
    def __init__(self, username: str, **kwargs):
        self.username = username


class Home(Controller):
    @get("/")
    async def index(self, request):
        return self.view("index", {}, request=request)

    @post("/user")
    async def create_user(self, data: FromForm[CreateUserInput]):
        """Calls to this endpoint require an anti-forgery token."""
        return {"example": True, "username": data.value.username}
```

`index.jinja` (like in the previous example).

## Rendering anti-forgery tokens without input elements

The tag `{% af_token %}` can be used to render an anti-forgery value without
rendering an HTML input element.
For example to render it inside JavaScript:

```html
<script>
    EXAMPLE = {"token": "{% af_token %}"}
</script>
```

## Excluding request handlers from validation

Use the `ignore_anti_forgery` decorator to exclude particular request handlers
from anti-forgery validation:

```python
from blacksheep.server.csrf import ignore_anti_forgery


@ignore_anti_forgery()
@post("/example")
async def create_example():
    """This endpoint does not require an anti-forgery token."""
```

## Custom AntiForgeryHandler classes

The following example shows how to override methods of the `AntiForgeryHandler`
class:

```python
from blacksheep.server.csrf import AntiForgeryHandler, use_anti_forgery


class CustomAntiForgeryHandler(AntiForgeryHandler):
    pass


use_anti_forgery(app, handler=CustomAntiForgeryHandler())
```
