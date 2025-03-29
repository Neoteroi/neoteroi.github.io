# HTTP Client

BlackSheep includes an implementation of HTTP Client for HTTP 1.1.

## Client features

- HTTP connection pooling
- User-friendly handling of SSL contexts (safe by default)
- Support for client side middlewares
- Automatic handling of redirects (can be disabled, validates circular
  redirects and maximum number of redirects - redirects to URN are simply
  returned to code using the client)
- Automatic handling of cookies (can be disabled, `Set-Cookie` and `Cookie`
  headers)

**Example:**
```python
import asyncio
from blacksheep.client import ClientSession


async def client_example(loop):
    async with ClientSession() as client:
        response = await client.get("https://docs.python.org/3/")

        assert response is not None
        text = await response.text()
        print(text)


loop = asyncio.get_event_loop()
loop.run_until_complete(client_example(loop))

```

## HTTP Connection pooling

The HTTP client in BlackSheep implements connection pooling. Meaning that
connections to the same host and port are kept in memory and reused for
different request-response cycles, when possible. By default, connections are
not disposed of as long as they are kept open.

Implementation:
[/blacksheep/client/pool.py](https://github.com/RobertoPrevato/BlackSheep/blob/master/blacksheep/client/pool.py).

Connections are created using `asyncio` function `loop.create_connection`.

## Client middlewares

The HTTP Client supports middlewares. Middlewares on the server are functions
that are executed in order, at every request-response cycle and enable
manipulation of incoming requests and outgoing responses. Middlewares support
interruption of the chain: that is, returning an HTTP response without firing
all handlers in the chain, for example, to return HTTP 401 Unauthorized when
applying an authentication strategy. The HTTP client can benefit from the same
design pattern, and this is supported in BlackSheep.

## Client middleware example

```python
async def client_example_middleware(request, next_handler):

    # do something before the request is sent
    response = await next_handler(request)

    # do something with the response from the remote server
    return response

client = ClientSession()
client.middlewares.append(client_example_middleware)
client.configure()
```

## Considerations about the ClientSession class

The `ClientSession` owns by default a connections pool, if none is specified for
it. The connections pool is automatically disposed of when the client is exited,
if it was created for the client.

!!! danger "Connection pooling is important"
    Avoid instantiating a new `ClientSession` at each web request, unless the
    same `ConnectionsPool` is reused among the instances. Instantiating a new
    `ClientSession` without reusing the same TCP connections pool has
    negative effects on the performance of the application.

It is recommended to instantiate a single instance of HTTP client and
register it as a service of the application, using the `@app.lifespan` method:

```python
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
```

When following this approach, the HTTP client can be automatically injected
into request handlers, and services that need it, and is automatically disposed
of when the application is stopped.
