# Server Side Rendering (SSR)

Server side templating refers to the ability of a web application to generate
HTML pages from templates and dynamic variables. By default, BlackSheep does
this using [`Jinja2` library](https://palletsprojects.com/p/jinja/) by the
[Pallets](https://palletsprojects.com) team, but it supports custom renderers.

This page describes:

- [X] How to configure server side templating.
- [X] Returning views using response functions.
- [X] Returning views using the MVC features.
- [X] Using alternatives to `Jinja2`.

!!! info
    The [BlackSheep MVC project
    template](https://github.com/RobertoPrevato/BlackSheepMVC) includes a
    ready-to-use solution having an application with templates and layout
    configured.

## Configuration

This example shows how to use Jinja2 templating engine with BlackSheep:

```python
from blacksheep import Application, get
from blacksheep.server.responses import view

app = Application()


@get("/")
def home():
    return view("home", {"example": "Hello", "foo": "World"})
```

The expected folder structure for this example:
```
⬑ app
     ⬑ views
          home.jinja   <-- template file loaded by `view` function
     __init__.py

server.py
```

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
</head>
<body>
  <h1>{{example}}</h1>
  <p>{{foo}}</p>
</body>
</html>
```

## Async mode

It is possible to enable Jinja2 [async
mode](http://jinja.pocoo.org/docs/2.10/api/#async-support), in the following
way:

```python
from blacksheep import Application, get
from blacksheep.server.rendering.jinja2 import JinjaRenderer
from blacksheep.server.responses import view_async
from blacksheep.settings.html import html_settings

app = Application()
html_settings.use(JinjaRenderer(enable_async=True))

@get("/")
async def home():
    return await view_async("home", {"example": "Hello", "foo": "World"})

```

## Loading templates

It is possible to load templates by name including '.jinja', or without file
extension; '.jinja' extension is added automatically. The extension must be
lowercase.

```python
@get("/")
async def home(request):
    return view("home.jinja", {"example": "Hello", "foo": "World"})


# or...


@get("/")
async def home(request):
    return view("home", {"example": "Hello", "foo": "World"})
```

## Helpers and filters

To configure custom helpers and filters for Jinja, access the renderer through
`blacksheep.settings.html.html_settings`:

```
.
├── app
│   ├── __init__.py
│   └── views
│       └── index.jinja
└── server.py
```

```python
from datetime import datetime

from blacksheep.server import Application
from blacksheep.server.rendering.jinja2 import JinjaRenderer
from blacksheep.settings.html import html_settings

def configure_templating(
    application: Application
) -> None:
    """
    Configures server side rendering for HTML views.
    """
    renderer = html_settings.renderer
    assert isinstance(renderer, JinjaRenderer)

    def get_copy():
        now = datetime.now()
        return "{} {}".format(now.year, "Example")

    helpers = {"_": lambda x: x, "copy": get_copy}

    env = renderer.env
    env.globals.update(helpers)
```

```html
<!-- index.jinja -->
<p>Hello, World!</p>
{{ copy() }}
```

## Using alternatives to Jinja2

To use alternative classes for server side rendering:

1. Define an implementation of `blacksheep.server.rendering.abc.Renderer`
2. Configure it using `from blacksheep.settings.html import html_settings`

```python
from blacksheep.server.csrf import AntiForgeryHandler
from blacksheep.settings.html import html_settings
from blacksheep.server.rendering.abc import Renderer


class CustomRenderer(Renderer):

    def render(self, template: str, model, **kwargs) -> str:
        """Renders a view synchronously."""
        ...

    async def render_async(self, template: str, model, **kwargs) -> str:
        """Renders a view asynchronously."""
        ...

    def bind_anti_forgery_handler(self, handler: AntiForgeryHandler) -> None:
        """
        Applies extensions for an anti-forgery handler.

        This method can be used to generate HTML fragments containing
        anti-forgery tokens, for the built-in implementation of AF validation.
        """


html_settings.use(CustomRenderer())
```
