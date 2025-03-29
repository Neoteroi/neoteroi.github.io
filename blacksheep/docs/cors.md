# Cross-Origin Resource Sharing

BlackSheep implements a strategy to handle [Cross-Origin Resource Sharing
(CORS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS). This page
describes:

- [X] How to enable CORS globally.
- [X] How to enable CORS for specific endpoints.

## Enabling CORS globally
The example below shows how to enable CORS globally on a BlackSheep application:

```python
app.use_cors(
    allow_methods="GET POST DELETE",
    allow_origins="https://www.example.dev",
    allow_headers="Authorization",
    max_age=300,
)
```

When enabled this way, the framework handles `CORS` requests, including
preflight `OPTIONS` requests.

It is possible to use `*` to enable any origin or any method:

```python
app.use_cors(
    allow_methods="*",
    allow_origins="*",
    allow_headers="* Authorization",
    max_age=300,
)
```

| Options           | Description                                                                                                                                              |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| allow_methods     | Controls the value of [Access-Control-Allow-Methods](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Methods). 🗡️          |
| allow_origins     | Controls the value of [Access-Control-Allow-Origin](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Origin). 🗡️            |
| allow_headers     | Controls the value of [Access-Control-Allow-Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Headers). 🗡️          |
| allow_credentials | Controls the value of [Access-Control-Allow-Credentials](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Credentials).    |
| expose_headers    | Controls the value of [Access-Control-Expose-Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Expose-Headers). 🗡️        |
| max_age           | Controls the value of [Access-Control-Max-Age](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Max-Age), defaults to 5 seconds. |

🗡️ The value can be a string of values separated by space, comma, or semi-colon, or a list.

## Enabling CORS for specific endpoints
The example below shows how to enable CORS only for certain endpoints:

```python

app.use_cors()
cors = app.cors

app.add_cors_policy(
    "example",
    allow_methods="GET POST",
    allow_origins="*",
)

@route("/", methods=["GET", "POST"])
async def home():
    ...

@cors("example")
@route("/specific-rules", methods=["GET", "POST"])
async def enabled():
    ...

```

Explanation:

1. the function call `app.use_cors()` activates built-in handling of CORS
   requests and registers a global CORS rule that doesn't allow anything by
   default
2. the call `app.add_cors_policy(...)` registers a new set of rules for CORS,
   associated to the key "example"
3. the set of rules for CORS called "example" is associated to specific
   request handlers using the `@cors` decorator

It is possible to register many sets of rules for CORS, each with its own key,
and apply different rules to request handlers.
It is also possible to define a global rule when calling `app.use_cors(...)`
that enables certain operations for all request handlers, while defining
specific rules.

```python

# the following settings are applied by default to all request handlers:
app.use_cors(
    allow_methods="GET POST",
    allow_origins="https://www.foo.org",
    allow_headers="Authorization",
)

app.add_cors_policy(
    "one",
    allow_methods="GET POST PUT DELETE",
    allow_origins="*",
    allow_headers="Authorization",
)

app.add_cors_policy("deny")


@route("/", methods=["GET", "POST"])
async def home():
    ...

@app.cors("one")
@route("/specific-rules", methods=["GET", "POST"])
async def enabled():
    ...

@app.cors("deny")
@get("/disabled-for-cors")
async def disabled():
    ...
```
