This page describes the most relevant differences between version 1 and
version 2 of the web framework. The most relevant changes are:

- [X] Improved project templates and the `blacksheep-cli` to bootstrap new projects.
- [X] Automatic import of `routes` and `controllers`.
- [X] Added functions to support the notion of application environment.
- [X] Improved dependency injection, with support for alternatives to `rodi`.
- [X] Improved server side rendering, with support for alternatives to `Jinja2`.
- [X] Added support for dependency injection in authentication and authorization handlers.
- [X] Removed the `@app.route` decorator and moved it to the `Router` class.
- [X] Improved the `Router` class to support sub-routers and filters.
- [X] Improved the OIDC features to support storing tokens in the HTML5 Storage
  API instead of cookies.
- [X] Some classes have been renamed to better follow Python naming conventions.

The full list of changes is at the bottom of this page. It includes changes
that were applied to version 1 of the framework, too.

## BlackSheep-CLI

The second version of the framework features improved project templates, with
a dedicated CLI for project scaffolding. For more information on the CLI, read
[_More about the CLI_](/blacksheep/cli/).

![CLI help](/blacksheep/img/cli-help.png)

The improved project templates also include a strategy to validate settings
using [`Pydantic`](https://docs.pydantic.dev/latest/).

## Automatic import of routes and controllers

The second version of the framework includes features to considerably reduce
code verbosity when defining routes and controllers.

The framework now exposes methods of a default singleton `Router` instance, to
be used to register routes independently from application instantiation. This
enables a much cleaner code API, and consistent with the existing API to
register controllers.

```python
from blacksheep import get, post


@get("/api/examples")
async def get_examples() -> list[str]:
    ...


@post("/api/examples")
async def add_example(self, example: str):
    ...
```

For more information on the above, read [_Using the default router and other routers_](/blacksheep/routing/#using-the-default-router-and-other-routers).

All modules inside `routes` and `controllers` packages are imported
automatically in v2. Automatic import works relative to where a BlackSheep
application is instantiated. In the structure described below, the modules in
`app.controllers` and `app.routes` namespace are imported automatically when an
application is instantiated inside `app.main`.

```
app/
├── __init__.py
├── controllers
│   ├── __init__.py
│   ├── home.py
│   └── example.py
├── routes
│   ├── __init__.py
│   └── example.py
└──main.py
```

The difference in code verbosity is considerable, because previously defining
routes and controllers explicitly was not sufficient to have them registered in
applications.

## Notion of application environment

The namespace `blacksheep.server.env` provides an abstraction layer to support
the notion of _application environment_. It provides functions that can be used
to apply logic depending on whether the application is running for local
development, or a different kind of environment (e.g. `dev`, `test`, `prod`).

These functions use the environment variable `APP_ENV` to determine the type
of environment, defaulting to `production` if such variable is missing.

```python
from blacksheep.server.env import is_development, is_production

# is_development returns true if APP_ENV (lower) is in {"local", "dev", "development"}
# is_production returns true if APP_ENV (lower) is missing or in {"prod", "production"}
```

## Changes to dependency injection

In v2, `rodi` and `BlackSheep` have been modified to enable alternative
implementations of dependency injection. `rodi` now defines a
`ContainerProtocol` with a basic API to register and resolve dependencies, and
`BlackSheep` relies on that protocol instead of its specific implementation in
`rodi`.

For more information, read the [_dedicated part in the Dependency Injection_](/blacksheep/dependency-injection/#the-container-protocol) page.

## Changes to server side rendering

`BlackSheep` v2 has been modified to not be strictly reliant on `Jinja2` for
template rendering. To achieve this, two new namespaces have been added:

- `blacksheep.server.rendering.abc`, defining an abstract `Renderer` class,
- `blacksheep.settings.html`, defining a code API to control renderer settings

The code API of the `view` and `view_async` functions in the
`blacksheep.server.responses` namespace has been improved, using the renderer
configured in `blacksheep.settings.html`.

The following examples show how a view can be rendered, having a template
defined at the path `views/home.jinja`:

=== "Now in v2"

    ```python
    from blacksheep import Application, get
    from blacksheep.server.responses import view

    app = Application()


    @get("/")
    def home():
        return view("home", {"example": "Hello", "foo": "World"})
    ```

=== "Before in v1"

    ```python
    from blacksheep import Application
    from blacksheep.server.templating import use_templates
    from jinja2 import PackageLoader

    app = Application()
    get = app.router.get

    view = use_templates(app, loader=PackageLoader("app", "views"))


    @get("/")
    def home():
        return view("home", {"example": "Hello", "foo": "World"})
    ```

Template:

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

For more information, read the updated
[_page describing Server Side Rendering_](/blacksheep/templating/).

## Improvements to authentication and authorization handlers

`GuardPost` has been modified to support the new `ContainerProtocol` in `rodi`,
and authentication and authorization handlers now support dependency injection.

## Removed the app.route method

The `Application` class was modified to remove the `route` method, which is now
available in the `Router` class. The reason for this change it to make the
code API consistent between methods used to register request handlers.
The `route` method of the singleton default `Router` instance is also exposed
by `blacksheep` package like the other methods to register request handlers.

=== "Now in v2"

    ```python
    from blacksheep import Application, route

    app = Application()


    @route("/")
    def home():
        return "Example"
    ```

=== "Before in v1"

    ```python
    from blacksheep import Application

    app = Application()


    @app.route("/")
    def home():
        return "Example"
    ```

## Improvements to the Router class

The `Router` class has been improved to support sub-routers and filters.
For more information, read [_Using sub-routers and filters_](/blacksheep/routing/#using-sub-routers-and-filters).

## Improvements to OIDC support

The functions that implement OpenID Connect (OIDC) support have been improved to
support storing tokens (id_token, access_token, refresh_token) in any kind of
store, and with built-in support for the HTML5 Storage API.

!!! into "Examples in GitHub"
    Refer to the [OIDC examples](https://github.com/Neoteroi/BlackSheep-Examples/tree/main/oidc)

The following **partial** example shows how to use the `use_openid_connect`
function to configure a web app to:

- use OpenID Connect with [Entra ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id) to implement authentication
- store `id_token`, `access_token`, and `refresh_token` using the HTML5
  Storage API
- configure the back-end API to use `JWT Bearer` authentication (clients must
  send requests with `Authorization: Bearer <JWT>` headers)

```python
"""
This example shows how to configure an OpenID Connect integration having tokens
exchanged with the client using the HTML5 Storage API, instead of response cookies.
This scenario enables better reusability of web APIs.
See how the id_token is used in ./static/index.html to authenticate following requests
('Authorization: Bearer ***' headers), and how the refresh token endpoint can be used
to obtain fresh tokens.
"""
import uvicorn
from blacksheep.server.application import Application
from blacksheep.server.authentication.jwt import JWTBearerAuthentication
from blacksheep.server.authentication.oidc import (
    JWTOpenIDTokensHandler,
    OpenIDSettings,
    use_openid_connect,
)
from dotenv import load_dotenv

from common.routes import register_routes
from common.secrets import Secrets

load_dotenv()
secrets = Secrets.from_env()
app = Application(show_error_details=True)


AUTHORITY = (
    "https://login.microsoftonline.com/b62b317a-19c2-40c0-8650-2d9672324ac4/v2.0"
)
CLIENT_ID = "499adb65-5e26-459e-bc35-b3e1b5f71a9d"
use_openid_connect(
    app,
    OpenIDSettings(
        authority=AUTHORITY,
        client_id=CLIENT_ID,
        client_secret=secrets.aad_client_secret,
        scope=(
            "openid profile offline_access email "
            "api://65d21481-4f1a-4731-9508-ad965cb4d59f/example"
        ),
    ),
    auth_handler=JWTOpenIDTokensHandler(
        JWTBearerAuthentication(
            authority=AUTHORITY,
            valid_audiences=[CLIENT_ID],
        ),
    ),
)

register_routes(app, static_home=True)


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5000, log_level="debug")

```

## Changes to follow naming conventions

Some classes have been renamed to better follow Python naming conventions. For
example the aliases 'HtmlContent' and 'JsonContent' that were kept for backward
compatibility in `v1`, as alternative names for `HTMLContent` and
`JSONContent`, were removed in `v2`.

## List of changes

The full list of changes in alpha versions released for `v2`:

- Renames the `plugins` namespace to `settings`.
- Upgrades `rodi` to v2, which includes improvements.
- Adds support for alternative implementation of containers for dependency
  injection, using the new `ContainerProtocol` in `rodi`.
- Upgrades `guardpost` to v1, which includes support for
  dependency injection in authentication handlers and authorization requirements.
- Adds support for Binders instantiated using dependency injection. However,
  binders are still instantiated once per request handler and are still
  singletons.
- Adds a method to make the `Request` object accessible through dependency
  injection (`register_http_context`). This is not a recommended practice,
  but it can be desired in some circumstances.
- Removes the direct dependency on `Jinja2` and adds support for alternative
  ways to achieve Server Side Rendering (SSR) of HTML; however, `Jinja2` is still
  the default library if the user doesn´t specify how HTML should be rendered.
- Adds options to control `Jinja2` settings through environment variables.
- Removes the deprecated `ServeFilesOptions` class.
- Improves how custom binders can be defined, reducing code verbosity for
  custom types. This is an important feature to implement common validation of
  common parameters across multiple endpoints.
- Adds support for binder types defining OpenAPI Specification for their
  parameters.
- Fixes bug #305 (`ClientSession ssl=False` not working as intended).
- Refactors the classes for OpenID Connect integration to support alternative
  ways to share tokens with clients, and JWT Bearer token authentication out
  of the box, in alternative to cookie-based authentication.
- It adds built-in support for storing tokens (`id_token`, `access_token`, and
  `refresh_token`) using the HTML5 Storage API (supporting `localStorage` and
  `sessionStorage`). Refresh tokens, if present, are automatically protected to
  prevent leaking. See [the OIDC
  examples](https://github.com/Neoteroi/BlackSheep-Examples/tree/main/oidc) for
  more information.
- Renames `blacksheep.server.authentication.oidc.TokensStore` to `TokensStore`.
- Removes the `tokens_store` parameter from the `use_openid_connect` method;
  it is still available as an optional parameter of the two built-in classes
  used to handle tokens.
- Replaces `request.identity` with `request.user`. The property `identity` is
  still kept for backward compatibility, but it will be removed in `v3`.
- Removes 'HtmlContent' and 'JsonContent' that were kept as alternative names
  for `HTMLContent` and `JSONContent`.
- Refactors the `ClientSession` to own by default a connections pool, if none
  is specified for it. The connections pool is automatically disposed of when
  the client is exited, if it was created for the client.
- Makes the `ClientSession` more user-friendly, supporting headers defined as
  `dict[str, str]` or `list[tuple[str, str]]`.
- Improves the type annotations of the `ClientSession`.
- Corrects a bug in the `ClientSession` that would cause a task lock when the
  connection is lost while downloading files.
- Corrects a bug in the `ClientSession` causing `set-cookie` headers to not be
  properly handled during redirects.
- Renames the client connection pool classes to remove the prefix "Client".
- Corrects bug of the `Request` class that would prevent setting `url` using a
  string instead of an instance of `URL`.
- Corrects bug of the `Request` class that prevented the `host` property from
  working properly after updating `url` (causing `follow_redirects` to not work
  properly in `ClientSession`.
- Upgrades the `essentials-openapi` dependency, fixing [#316](https://github.com/Neoteroi/BlackSheep/issues/316).
- Corrects the `Request` class to not generate more than one `Cookie` header
  when multiple cookies are set, to [respect the specification](https://www.rfc-editor.org/rfc/rfc6265#section-5.4).
- Adds `@app.lifespan` to support registering objects that must be initialized
  at application start, and disposed of at application shutdown.
  The solution supports registering as many objects as desired.
- Adds features to handle `cache-control` response headers: a decorator for
  request handlers and a middleware to set a default value for all `GET`
  requests resulting in responses with status `200`.
- Adds features to control `cache-control` header for the default document
  (e.g. `index.html`) when serving static files;
  see [issue 297](https://github.com/Neoteroi/BlackSheep/issues/297).
- Fixes bug in `sessions` that prevented updating the session data when using
  the `set` and `__delitem__` methods;
  [scottrutherford](https://github.com/scottrutherford)'s contribution.

`@app.lifespan` example:

```python
from blacksheep import Application
from blacksheep.client.session import ClientSession

app = Application()


@app.lifespan
async def register_http_client():
    async with ClientSession() as client:
        print("HTTP client created and registered as singleton")
        app.services.register(ClientSession, instance=client)
        yield

    print("HTTP client disposed of")


@router.get("/")
async def home(http_client: ClientSession):
    print(http_client)
    return {"ok": True, "client_instance_id": id(http_client)}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=44777, log_level="debug", lifespan="on")
```

- Adds support for user-defined filters for server routes (`RouteFilter` class).
- Adds built-in support for routing based on request headers.
- Adds built-in support for routing based on request query parameters.
- Adds built-in support for routing based on host header value.
- Adds a `query.setter` to the `Request` class, to set queries using
  `dict[str, str | sequence[str]]` as input.
- The functions registered to application events don't need anymore to define
  the `app` argument (they can be functions without any argument).
- Adds `Cache-Control: no-cache, no-store' to all responses generated for the
  OpenID Connect flow.
- Adds support for automatic import of modules defined under `controllers` and
  `routes` packages, relative to where the `Application` class is instantiated.
  Fix #334.
- Adds a `GzipMiddleware` that can be used to enable `gzip` compression, using
  the built-in module. Contributed by @tyzhnenko :sparkles:
- Improves how tags are generated for OpenAPI Documentation: adds the
  possibility to document tags explicitly and control their order, otherwise
  sorts them alphabetically by default, when using controllers or specifying
  tags for routes. Contributed by @tyzhnenko :sparkles:
- Adds a strategy to control features depending on application environment:
  `is_development`, `is_production` depending on `APP_ENV` environment
  variable. For more information, see [_Defining application
  environment_](https://www.neoteroi.dev/blacksheep/settings/#defining-application-environment).
- Makes the client `ConnectionPools` a context manager, its `__exit__` method
  closes all its `TCP-IP` connections.
- Improves exception handling so it is possible to specify how specific types
  of `HTTPException` must be handled (#342).
- Improves the error message when a list of objects if expected for an incoming
  request body, and a non-list value is received (#341).
- Replaces `chardet` and `cchardet` with `charset-normalizer`. Contributed by
  @mementum.
- Upgrades all dependencies.
- Adopts `pyproject.toml`.
- Fixes bug in CORS handling when [multiple origins are
  allowed](https://github.com/Neoteroi/BlackSheep/issues/364).
- Adds a `Vary: Origin` response header for CORS requests when the value of
  `Access-Control-Allow-Origin` header is a specific URL.
- Adds algorithms parameter to JWTBearerAuthentication constructor, by @tyzhnenko.
- Improves the code API to define security definitions in OpenAPI docs, by @tyzhnenko.
- Applies a correction to the auto-import function for routes and controllers.
- Add support for `StreamedContent` with specific content length; fixing
  [#374](https://github.com/Neoteroi/BlackSheep/issues/374) both on the client
  and the server side.
- Fix [#373](https://github.com/Neoteroi/BlackSheep/issues/373), about missing
  closing ASGI message when an async generator does not yield a closing empty
  bytes sequence (`b""`).
- Make version dynamic in `pyproject.toml`, simplifying how the version can be
  queried at runtime (see [#362](https://github.com/Neoteroi/BlackSheep/issues/362)).
- Fix [#372](https://github.com/Neoteroi/BlackSheep/issues/372). Use the ASGI
  scope `root_path` when possible, as `base_path`.
- Fix [#371](https://github.com/Neoteroi/BlackSheep/issues/371). Returns status
  403 Forbidden when the user is authenticated but not authorized to perform an
  action.
- Fixes `TypeError` when writing a request without a host header.
- Add support for `Pydantic` `v2`: meaning feature parity with support for
  Pydantic v1 (generating OpenAPI Documentation).
- Add support for `Union` types in sub-properties of request handlers input and
  output types, for generating OpenAPI Documentation, both using simple classes
  and Pydantic [#389](https://github.com/Neoteroi/BlackSheep/issues/389)
- Resolves bug in `2.0a10` caused by incompatibility issue with `Cython 3`.
- Pins `Cython` to `3.0.2` in the build job.
- Fixes bug #394, causing the `Content` max body size to be 2147483647.
  (C int max value). Reported and fixed by @thomafred.
- Add support for `.jinja` extension by @thearchitector.
- Makes the `.jinja` extension default for Jinja templates.
- Adds support for Python 3.12, by [@bymoye](https://github.com/bymoye)
- Replaces `pkg_resources` with `importlib.resources` for all supported Python
  versions except for `3.8`.
- Runs tests against Pydantic `2.4.2` instead of Pydantic `2.0` to check
  support for Pydantic v2.
- Adds `.webp` and `.webm` to the list of extensions of files that are served
  by default.
