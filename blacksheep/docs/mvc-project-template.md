# Getting started with the MVC project template

This tutorial explains how to create a BlackSheep application using the
MVC ([_Model, View, Controller_](https://en.wikipedia.org/wiki/Model–view–controller))
project template, covering the following topics:

- [X] Creating an application from a project template, using the BlackSheep CLI.
- [X] Routes defined using classes (controllers).
- [X] Server side templating (views and models).
- [X] Handling parameters in controllers.
- [X] Serving static files

It is recommended to follow the [previous tutorial](../getting-started) before
reading this one.

### Requirements

* [Python](https://www.python.org) version >= **3.10** (3.8 and 3.9 are
  supported but not recommended to follow this tutorial)
* path to the python executable configured in the environment `$PATH` variable
  (tip: if you install Python on Windows using the official installer, enable
  the checkbox to update your `$PATH` variable automatically)
* a text editor: any is fine; this tutorial uses [Visual Studio Code](https://code.visualstudio.com/Download)

## Introduction to the BlackSheep CLI

The previous tutorial described the basics of creating an application from
scratch. While that knowledge is important, it is usually not desirable to
start every project from scratch. BlackSheep offers a command-line interface
(CLI) that can be used to start new projects. The CLI can be installed from the
[Python Package Index](https://pypi.org/project/blacksheep-cli/) using the
`blacksheep-cli` package:

```bash
pip install blacksheep-cli
```

Once installed, the `create` command can be used to start new projects:

```bash
blacksheep create
```

The CLI will prompt for input about various options. For the sake of this
tutorial, answer:

- `tutorial` for project name
- `mvc` for the project template
- `Yes` for OpenAPI Documentation
- `essentials-configuration` to read settings
- `YAML` for app settings format

```
✨ Project name: tutorial
🚀 Project template: mvc
📜 Use OpenAPI Documentation? Yes
🔧 Library to read settings essentials-configuration
🔩 App settings format (Use arrow keys)
 » YAML
   TOML
   JSON
   INI
```

!!! tip "blacksheep create"
    It is possible to use the `create` command specifying the project name
    and template directly, like in:

    - `blacksheep create some_name`
    - `blacksheep create some_name --template api`

![MVC template](./img/mvc-template-v2.png)

After a project is created, the CLI displays a message with instructions.

```
──────────────────────────────────────────────────────────────────────
🏗️  Project created in tutorial
──────────────────────────────────────────────────────────────────────
-- What's next:
        cd tutorial
        pip install -r requirements.txt
        python dev.py
```

Install the project dependencies:

- `cd` into the project folder
- create a new [Python virtual environment](https://docs.python.org/3/library/venv.html) (recommended but optional)
- install its dependencies with `pip install -r requirements.txt`

## Starting the application

Start the application using one of the following commands:

```bash
# using the provided dev.py file (useful to debug)
python dev.py

# or using the uvicorn CLI
uvicorn app.main:app --port 44777 --lifespan on --reload
```

And navigate to the local page, opening a browser at [`http://localhost:44777`](http://localhost:44777)
(use the same port of the previous command).

The browser should display this page:

![MVC Project home](./img/mvc-template-home.png)

Several things are happening because the web application is configured:

- to build and serve dynamic HTML pages
- to serve static files (e.g. pictures, JavaScript, CSS files)
- to expose an API and offer OpenAPI Documentation about the API
- to handle application settings and application start/stop events

Let's see these elements in order, but first let's get acquainted with the
project's structure.

## Project structure
The project is organized with the following folder structure:

```
├── app
│   ├── (application files)
│   │
│   ├── controllers
│   │   └── (controller files, defining routes)
│   │
│   ├── docs
│   │   └── (files for OpenAPI Documentation)
│   │
│   ├── static
│   │   └── (static files served by the web app)
│   │
│   └── views
│       └── (HTML templates, views compiled by the web app)
│
├── domain
│   └── (domain classes, POCO)
│
├── (root folder, where the main file starting the whole app resides)
├── dev.py  (file that can be used to start a development server, useful for debugging)
└── settings.dev.yaml (settings used when the env variable APP_ENV == dev)
└── settings.yaml (base settings file)
```

- the `app` folder contains files that are specific to the web application,
  settings, a folder for `controllers` that define routes, folders for `static`
  files and one for `views` (HTML templates)
- other packages at the root of the project, like `domain`, should be
  abstracted from the web server and should be reusable in other kinds of
  applications (for example, a CLI)
- the root folder contains the `dev.py` file to start the application in
  development mode, and settings files with `.yaml` extension that are read
  when the application starts (since the YAML format was selected when using
  the `blacksheep create` command)

The project uses `onion architecture`. For example, a valid scenario would be
to add an additional package for the data access layer, and implement the
business logic in modules inside the `domain` folder.

## Open the project with a text editor
Open the project's folder using your favorite text editor.

![Visual Studio Code](./img/vs-code-mvc.png)

## Routes defined using classes (controllers)

The previous tutorial described how routes can be defined using functions:

```python
@get("/")
async def home():
    ...
```

`blacksheep` offers an alternative way to define request handlers: using class
methods. Both approaches have pros and cons, which will be described later in
more detail. To see this in practice, create a new file
`app/controllers/greetings.py` and copy the following code into it:

```python
from blacksheep.server.controllers import Controller, get


class Greetings(Controller):

    @get("/hello-world")
    def index(self):
        return self.text("Hello, World!")

```

Stop and restart the application, then navigate to
[`http://localhost:44777/hello-world`](http://localhost:44777/hello-world): it
will display the response from the `Greetings.index` method.

When the path of a web request matches a route defined in a controller type, a
new instance of that `Controller` is created. In other words, every instance of
controller is scoped to a specific web request. Just like function handlers,
controllers support the automatic injection of parameters into request
handlers, and also dependency injection into their constructors (`__init__`
methods). This is a feature that improves development speed and enables cleaner
code (compare this approach with a scenario where all dependencies need to be
imported and referenced inside function bodies by hand).

The `Controller` class implements methods to return values and offers
`on_request` and `on_response` extensibility points.

!!! tip "Controllers and routes automatic import"
    Python modules defined inside `controllers` and `routes` packages are
    automatically imported by a BlackSheep application. The automatic import
    happens relative to the namespace where the application is instantiated.

## Server side templating (views and models)

Server side templating refers to the ability of a web application to generate
HTML pages from templates and dynamic variables. By default, BlackSheep does
this using the [`Jinja2` library](https://palletsprojects.com/p/jinja/)
by the [Pallets](https://palletsprojects.com) team.

To see how this works in practice when using `Controllers`, edit the `Greetings`
controller created previously to look like this:

```python
from blacksheep.server.controllers import Controller, get


class Greetings(Controller):

    @get("/hello-view")
    def hello(self):
        return self.view()
```

Then, create a new folder inside `views` directory, called "greetings", and
add an HTML file named "hello.jinja".

![New view](./img/new-view.png)

Copy the following contents into `hello.jinja`:

```html
<div>
  <h1>Hello, There</h1>
</div>
```

Now navigate to [http://localhost:44777/hello-view](http://localhost:44777/hello-view),
to see the response from the new HTML view.

Note how convention over configuration is used in this case, to determine that
`./views/greetings/hello.jinja` file must be used, because of the convention:<br />
`./views/{CONTROLLER_NAME}/{METHOD_NAME}.jinja`.

The view currently is an HTML fragment, not a full document. To make it a
full page, modify `hello.jinja` to use the application layout:

```html
{%- extends "layout.jinja" -%}
{%- block title -%}
  Hello Page!
{%- endblock -%}
{%- block description -%}
  Project template to create web applications with MVC architecture using BlackSheep web framework.
{%- endblock -%}
{%- block css -%}
  <link rel="stylesheet" href="/styles/public.css" />
{%- endblock -%}
{%- block body -%}
  <div style="margin: 10em 2em;">
    <h1>Hello, There!</h1>
  </div>
{%- endblock -%}
{%- block js -%}

{%- endblock -%}
```

Refresh the page at [http://localhost:44777/hello-view](http://localhost:44777/hello-view) to see the result.

In this case, a page layout is applied using: `{%- extends "layout.jinja" -%}`,
with several blocks going in various areas of `layout.jinja`. For more
information on layouts and features of the templating library, refer to the
[Jinja2 documentation](https://jinja2docs.readthedocs.io/en/stable/).

---

So far the tutorials only showed the _Controller_ and the _View_ part of the _MVC_ architecture. A _Model_ is a context for an HTML view.
To include dynamic content into an HTML template, use mustaches _`{{name}}`_
placeholders and pass a model having properties whose names match their key
to the `view` function.

For example, modify `hello.jinja` to use dynamic content from a model:

```html
  <div style="margin: 10em 2em;">
    <h1>Hello, {{name}}!</h1>

    <ul>
      {% for sentence in sentences %}
        <li><a href="{{ sentence.url }}">{{ sentence.text }}</a></li>
      {% endfor %}
    </ul>
  </div>
```

and `greetings.py` to contain the following code:

```python
from dataclasses import dataclass
from typing import List
from blacksheep.server.controllers import Controller, get


@dataclass
class Sentence:
    text: str
    url: str


@dataclass
class HelloModel:
    name: str
    sentences: List[Sentence]


class Greetings(Controller):

    @get("/hello-view")
    def hello(self):
        return self.view(
            model=HelloModel(
                "World!",
                sentences=[
                    Sentence(
                        "Check this out!",
                        "https://github.com/RobertoPrevato/BlackSheep",
                    )
                ],
            )
        )
```

Produces this result:
![Hello Model](./img/hello-model.png)

Models can be defined as [dictionaries](https://docs.python.org/3.9/library/stdtypes.html#dict),
[dataclasses](https://docs.python.org/3/library/dataclasses.html),
[pydantic models](https://pydantic-docs.helpmanual.io), or regular classes
implementing a constructor.

## Handling parameters in controllers
The previous tutorial showed how request handlers support the automatic
injection of parameters read from the HTTP request. Controllers support the
same, therefore it is possible to have parameters read automatically and
injected into controller methods:

```python
class Example(Controller):

    @get("/example/{value}")
    def route_example(self, value: str):
        return self.text(f"Got: {value} in route")

    @get("/example")
    def query_example(self, value: str):
        return self.text(f"Got: {value} in query string")
```

Controllers also support dependency injection for their constructor
(`__init__` method), this will be explained in the next page.

## Serving static files
This tutorial previously showed how the homepage of the MVC project template looks
like, at the root of the website:

![MVC Project home](./img/mvc-template-home.png)

The project template includes a folder for `static` files, including pictures,
CSS, and JavaScript files. Static files are served using a catch-all route, reading
files whose path, relative to the static folder, matches the URL path of the request.

For example, if the `static` folder contains the file `scripts/example.js`,
web requests at `http://localhost:44777/scripts/example.js` will be resolved
with this file and related information. When handling static files, BlackSheep
automatically takes care of several details:

- it handles the ETag response header, If-None-Match request header and HTTP 304 Not
  Modified responses if files don't change on the file system
- it handles HTTP GET requests returning file information
- it handles Range requests, to support pause and restore downloads out of the box
  and enable optimal support for videos (videos can be downloaded from a certain
  point in time)

Try to add a file to the static folder, and download it writing the path in your
browser.

Relative paths are supported, but only files inside the root static folder are
served, it is not possible to download files outside of the static folder (it would be
a security issue if it worked otherwise!).
Additionally, BlackSheep only handles certain file extensions:  by default
only the most common file extensions used in web applications.
Paths starting with "/" are always considered absolute paths starting from the
root of the website.

## Strategy for application settings

The `API` and the `MVC` project templates include a strategy to read and
validate application settings, from various sources, and support multiple
system environments (like `dev`, `test`, and `prod` environments).

- [`Pydantic`](https://docs.pydantic.dev/latest/) is always used to describe and validate application settings.
- Application settings can be read from various sources using either
  `Pydantic v1 BaseSettings` class, or `essentials-configuration`.
- When using `essentials-configuration`, use the `APP_ENV` environment variable
  to control the application environment and to use environment-specific
  settings from dedicated files using the pattern:
  `settings.{{env_name}}.{{format}}`, like `settings.test.yaml`,
  `settings.prod.toml`.

For more information on application settings and the recommended way to apply
configuration depending on the application environment, refer to [_Settings_](/blacksheep/settings/).

## Summary

This tutorial covered some higher-level topics of a BlackSheep application. The
general concepts presented here apply to many kinds of web frameworks:

- server side templating of HTML views
- serving of static files
- use of MVC architecture

The next pages describe the built-in support for
[dependency injection](../dependency-injection), and automatic generation of
[OpenAPI Documentation](../openapi).

!!! info "For more information..."
    For more information about Server Side Rendering, read [_Templating_](/blacksheep/templating/).<br>
    For more information about the BlackSheep CLI, read [_More about the CLI_](/blacksheep/cli/).

!!! tip "Don't miss the api project template"
    Try also the `api` project template, to start new Web API projects that
    don't handle HTML views.
