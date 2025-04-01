# Routing

Server side routing refers to the ability of a web application to handle web
requests using different functions, depending on the URL path and HTTP method.
Each `BlackSheep` application is bound to a router, which provides several ways
to define routes. A function that is bound to a route is called a "request
handler", since its responsibility is to handle web requests and produce
responses.

This page describes:

- [X] How to define request handlers.
- [X] How to use route parameters.
- [X] How to define a catch-all route.
- [X] How to define a fallback route.
- [X] How to use sub-routers and filters.
- [X] How to use the default router and other routers.

## Defining request handlers

A request handler is a function used to produce responses. To become request
handlers, functions must be bound to a _route_, that represents a certain
URL path pattern. The `Router` class provides several methods to define request
handlers: with decorators (🗡️ in the table below) and without decorators
(🛡️):

| Router method   | HTTP method | Type |
| --------------- | ----------- | ---- |
| **head**        | HEAD        | 🗡️    |
| **get**         | GET         | 🗡️    |
| **post**        | POST        | 🗡️    |
| **put**         | PUT         | 🗡️    |
| **delete**      | DELETE      | 🗡️    |
| **trace**       | TRACE       | 🗡️    |
| **options**     | OPTIONS     | 🗡️    |
| **connect**     | CONNECT     | 🗡️    |
| **patch**       | PATCH       | 🗡️    |
| **add_head**    | HEAD        | 🛡️    |
| **add_get**     | GET         | 🛡️    |
| **add_post**    | POST        | 🛡️    |
| **add_put**     | PUT         | 🛡️    |
| **add_delete**  | DELETE      | 🛡️    |
| **add_trace**   | TRACE       | 🛡️    |
| **add_options** | OPTIONS     | 🛡️    |
| **add_connect** | CONNECT     | 🛡️    |
| **add_patch**   | PATCH       | 🛡️    |


### With decorators

The following example shows how to define a request handler for the root
path of a web application "/":

```python
from blacksheep import get


@get("/")
def hello_world():
    return "Hello World"
```

Alternatively, the application router offers a `route` method:

```python
from blacksheep import route


@route("/example", methods=["GET", "HEAD", "TRACE"])
async def example():
    # HTTP GET /example
    # HTTP HEAD /example
    # HTTP TRACE /example
    return "Hello, World!"
```

### Without decorators
Request handlers can be registered without decorators:

```python
def hello_world():
    return "Hello World"


app.router.add_get("/", hello_world)
app.router.add_options("/", hello_world)
```

### Request handlers as class methods
Request handlers can also be configured as class methods, defining classes that
inherit the `blacksheep.server.controllers.Controller` class (name taken from
the MVC architecture):

```python
from dataclasses import dataclass

from blacksheep import Application, text, json
from blacksheep.server.controllers import Controller, get, post


app = Application()


# example input contract:
@dataclass
class CreateFooInput:
    name: str
    nice: bool


class Home(Controller):

    def greet(self):
        return "Hello World"

    @get("/")
    async def index(self):
        # HTTP GET /
        return text(self.greet())

    @get("/foo")
    async def foo(self):
        # HTTP GET /foo
        return json({"id": 1, "name": "foo", "nice": True})

    @post("/foo")
    async def create_foo(self, foo: CreateFooInput):
        # HTTP POST /foo
        # with foo instance automatically injected parsing the request body as JSON
        # if the value cannot be parsed as CreateFooInput, Bad Request is returned automatically
        return json({"status": True})
```

## Route parameters

BlackSheep supports three ways to define route parameters:

* `"/:example"` - using a single colon after a slash
* `"/{example}"` - using curly braces
* `"/<example>"` - using angle brackets (i.e. [Flask notation](https://flask.palletsprojects.com/en/1.1.x/quickstart/?highlight=routing#variable-rules))

Route parameters can be read from `request.route_values`, or injected
automatically by the request handler's function signature:

```python

@get("/{example}")
def handler(request):
    # reading route values from the request object:
    value = request.route_values["example"]

    return text(value)


@get("/api/cats/{cat_id}")
def get_cat(cat_id):
    # cat_id is injected automatically
    ...
```

It is also possible to specify the expected type, using `typing` annotations:

```python

@get("/api/cats/{cat_id}")
def get_cat(cat_id: int):
    ...

```

```python
from uuid import UUID


@get("/api/cats/{cat_id}")
def get_cat(cat_id: UUID):
    ...

```

In this case, BlackSheep will automatically produce an `HTTP 400 Bad Request`
response if the input cannot be parsed into the expected type, producing a
response body similar to this one:

```
Bad Request: Invalid value ['asdas'] for parameter `cat_id`; expected a valid
UUID.
```

## Value patterns
By default, route parameters are matched by any string until the next slash "/"
character. Having the following route:

```python

@get("/api/movies/{movie_id}/actors/{actor_id}")
def get_movie_actor_details(movie_id: str, actor_id: str):
    ...

```

HTTP GET requests having the following paths are all matched:

```
/api/movies/12345/actors/200587

/api/movies/Trading-Places/actors/Denholm-Elliott

/api/movies/b5317165-ad31-47e2-8a2d-42dba8619b31/actors/a601d8f2-a1ab-4f20-aebf-60eda8e89df0
```

However, the framework supports more granular control on the expected value
pattern. For example, to specify that `movie_id` and `actor_id` must be
integers, it is possible to define route parameters this way:

```python
"/api/movies/{int:movie_id}/actors/{int:actor_id}"
```

!!! warning
    Value patterns only affect the regular expression used to match
    requests' URLs. They don't affect the type of the parameter after a web
    request is matched. Use type annotations as described above to enforce types
    of the variables as they are passed to the request handler.

The following value patterns are built-in:

| Value pattern | Description                                                                       |
| ------------- | --------------------------------------------------------------------------------- |
| `str`         | Any value that doesn't contain a slash "/".                                       |
| `int`         | Any value that contains only numeric characters.                                  |
| `float`       | Any value that contains only numeric characters and eventually a dot with digits. |
| `path`        | Any value to the end of the path.                                                 |
| `uuid`        | Any value that matches the UUID value pattern.                                    |

To define custom value patterns, extend the `Route.value_patterns` dictionary.
The key of the dictionary is the name used by the parameter, while the value is
a [regular expression](https://docs.python.org/3/library/re.html) used to match
the parameter's fragment. For example, to define a custom value pattern for
route parameters composed of exactly two letters between `a-z` and `A-Z`:

```python
Route.value_patterns["example"] = r"[a-zA-Z]{2}"
```

And then use it in routes:

```python
"/{example:foo}"
```

## Catch-all routes

To define a catch-all route that will match every request, use a route
parameter with a path value pattern, like:

* `{path:name}`, or `<path:name>`

```python
from blacksheep import text


@get("/catch-all/{path:sub_path}")
def catch_all(sub_path: str):
    return text(sub_path)
```

For example, a request at `/catch-all/anything/really.js` would be matched by
the route above, and the `sub_path` value would be `anything/really.js`.

It is also possible to define a catch-all route using a star sign `*`. To read
the portion of the path caught by the star sign from the request object, read
the "tail" property of `request.route_values`. But in this case the value of the
caught path can only be read from the request object.

```python

@get("/catch-all/*")
def catch_all(request):
    sub_path = request.route_values["tail"]

```

## Defining a fallback route

To define a fallback route that handles web requests not handled by any other
route, use `app.router.fallback`:

```python
def fallback():
    return "OOPS! Nothing was found here!"


app.router.fallback = fallback
```

## Using sub-routers and filters

The `Router` class supports filters for routes and sub-routers. In the following
example, a web request for the root of the service "/" having a request header
"X-Area" == "Test" gets the reply of the `test_home` request handler, and
without such header the reply of the `home` request handler is returned.

```python
from blacksheep import Application, Router


test_router = Router(headers={"X-Area": "Test"})

router = Router(sub_routers=[test_router])

@router.get("/")
def home():
    return "Home 1"

@test_router.get("/")
def test_home():
    return "Home 2"


app = Application(router=router)

```

A router can have filters based on headers, host name, query string parameters,
and custom user-defined filters.

Query string filters can be defined using the `params` parameter, and host name
filters can be defined using the `host` parameter:

```python
filter_by_query = Router(params={"version": "1"})

filter_by_host  = Router(host="neoteroi.xyz")
```

To define a custom filter, define a type of `RouteFilter` and set it using the
`filters` parameter:

```python
from blacksheep import Application, Request, Router
from blacksheep.server.routing import RouteFilter


class CustomFilter(RouteFilter):

    def handle(self, request: Request) -> bool:
        # implement here the desired logic
        return True


example_router = Router(filters=[CustomFilter()])
```

## Using the default router and other routers

The examples in the documentation show how to register routes using methods
imported from the BlackSheep package:

```python
from blacksheep import get

@get("")
async def home():
    ...
```

Or, for controllers:

```python
from blacksheep.server.controllers import Controller, get


class Home(Controller):

    @get("/")
    async def index(self):
        ...
```

In this case, routes are registered using default singleton routers, used if an
application is instantiated without specifying a router:

```python
from blacksheep import Application


# This application uses the default singleton routers exposed by BlackSheep:
app = Application()
```

This works in most scenarios, when a single `Application` instance per process
is used. For more complex scenarios, it is possible to instantiate a router
and use it as desired:

```python
# app/router.py

from blacksheep import Router


router = Router()
```

And use it when registering routes:

```python
from app.router import router


@router.get("/")
async def home():
    ...
```

It is also possible to expose the router methods to reduce code verbosity, like
the BlackSheep package does:

```python
# app/router.py

from blacksheep import Router


router = Router()


get = router.get
post = router.post

# ...
```


```python
from app.router import get


@get("/")
async def home():
    ...
```

Then specify the router when instantiating the application:

```python
from blacksheep import Application

from app.router import router


# This application uses the router instantiated in app.router:
app = Application(router=router)
```

### Controllers dedicated router

Controllers need a different kind of router, an instance of
`blacksheep.server.routing.RoutesRegistry`. If using a dedicated router for
controllers is desired, do this instead:

```python
# app/controllers.py

from blacksheep import RoutesRegistry


controllers_router = RoutesRegistry()


get = controllers_router.get
post = controllers_router.post

# ...
```

Then when defining your controllers:

```python
from blacksheep.server.controllers import Controller

from app.controllers import get, post


class Home(Controller):

    @get("/")
    async def index(self):
        ...
```

```python
from blacksheep import Application

from app.controllers import controllers_router


# This application uses the controllers' router instantiated in app.controllers:
app = Application()
app.controllers_router = controllers_router
```

!!! info "About Router and RoutesRegistry"

    Controller routes use a "RoutesRegistry" to support the dynamic generation
    of paths by controller class name. Controller routes are evaluated and
    merged into `Application.router` when the application starts.
