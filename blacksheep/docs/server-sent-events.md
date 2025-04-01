# Server-Sent Events

[**Server-Sent Events**](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
(SSE) enable creating a persistent, one-way connection between a client and a
server. When using SSE, a client can receive automatic updates from a server
via an HTTP connection.

BlackSheep implements built-in support for server-side events since version
`2.0.6`, offering features to simplify their use. This page describes how to
use the built-in features for server-sent events.

!!! tip
    Older versions of the web framework can also be configured to use SSE,
    because they all support response streaming, but don't offer dedicated
    features to simplify their use.

## Defining a server-sent events route

The following example describes how to configure a route for server-sent events,
defining a request handler as asynchronous generator:

```python
import asyncio
from collections.abc import AsyncIterable

from blacksheep import Application, get
from blacksheep.server.sse import ServerSentEvent

app = Application()


# A request handler defined as async generator yielding ServerSentEvent...
@get("/events")
async def events_handler() -> AsyncIterable[ServerSentEvent]:
    for i in range(3):
        yield ServerSentEvent({"message": f"Hello World {i}"})
        await asyncio.sleep(1)
```

1. Import `ServerSentEvent` from `blacksheep.server.sse`.
2. Import `AsyncIterable` from `collections.abc`, or from `typing` if support
   for Python 3.8 is desired.
3. Define a request handler as asynchronous generator with a return type
   annotation of `AsyncIterable[ServerSentEvent]` (the function must be `async`
   and must include at least one `yield` statement like above).

In this case the return type annotation on the request handler is mandatory
because the request handler is automatically normalized by BlackSheep.

BlackSheep supports request handlers defined as asynchronous generators since
version `2.0.6` especially for this use case, to support less verbose code
when using server-sent events. Previous versions already supported response
streaming, but required returning a `Response` bound to a `StreamedContent` and
an asynchronous generator yielding bytes. Using `async generators` with custom
classes require configuring the type of `Response` that is used to convert
those classes into bytes, like described in [the responses page](/responses/#chunked-encoding).

The following example shows how to define a server-sent event route controlling
the `Response` object.

## Defining a server-sent events route controlling the Response object

To define a server-sent events route and maintain control of the `Response`
object, refer to the following example:

```python
import asyncio
from collections.abc import AsyncIterable

from blacksheep import Application, get
from blacksheep.server.sse import ServerSentEvent, ServerSentEventsResponse

app = Application()


# An AsyncGenerator yielding ServerSentEvent...
async def events_provider() -> AsyncIterable[ServerSentEvent]:
    for i in range(3):
        yield ServerSentEvent({"message": f"Hello World {i}"})
        await asyncio.sleep(1)


# A request handler returning a streaming response bound to the generator...
@get("/events")
def events_handler():
    return ServerSentEventsResponse(events_provider)
```

In this case the return type annotation is optional.

!!! tip
    If you need to access the request object or other injected objects inside
    the generator, use `functools.partial` for the function argument of the
    `ServerSentEventsResponse`.

## Using controllers

Server-sent events routes are also supported in controllers.

```python
import asyncio
from collections.abc import AsyncIterable

from blacksheep import Application, Request
from blacksheep.server.process import is_stopping
from blacksheep.server.sse import ServerSentEvent
from blacksheep.server.controllers import Controller, get

app = Application()


class Home(Controller):
    @get("/events")
    async def events_handler(self, request: Request) -> AsyncIterable[ServerSentEvent]:
        i = 0

        while True:
            if await request.is_disconnected():
                print("The request is disconnected!")
                break

            if is_stopping():
                print("The application is stopping!")
                break

            i += 1
            yield ServerSentEvent({"message": f"Hello World {i}"})

            try:
                await asyncio.sleep(1)
            except asyncio.exceptions.CancelledError:
                break
```

## The ServerSentEvent class

| Property  | Description                                                                                     |
| --------- | ----------------------------------------------------------------------------------------------- |
| `data`    | An object that will be transmitted to the client, in JSON.                                      |
| `event`   | Optional event type name.                                                                       |
| `id`      | Optional event ID to set the EventSource's last event ID value.                                 |
| `retry`   | Optional reconnection delay time, in milliseconds, when a the connection to the server is lost. |
| `comment` | Optional comment.                                                                               |

For more information on events properties, please refer to the [MDN documentation](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events).

## Handling client disconnections and application shutdown

When using a technique that relies on persistent HTTP connections, it is
generally necessary to handle:

- client disconnections, to stop handling requests that were disconnected.
- application shutdown gracefully, to close pending connections.

To check if a request is disconnected, use the `request.is_disconnected()`
method where appropriate.

To check if the server process is shutting down, use the `is_stopping` function
from `blacksheep.server.process`.

```python
from blacksheep.server.process import is_stopping
```

The following example demonstrates a basic usage of both features:

```python
import asyncio
from collections.abc import AsyncIterable

from blacksheep import Application, Request, get
from blacksheep.server.process import is_stopping
from blacksheep.server.sse import ServerSentEvent

app = Application()


@get("/events")
async def events_handler(request: Request) -> AsyncIterable[ServerSentEvent]:
    i = 0

    while True:
        if await request.is_disconnected():
            print("The request is disconnected!")
            break

        if is_stopping():
            print("The application is stopping!")
            break

        i += 1
        yield ServerSentEvent({"message": f"Hello World {i}"})

        try:
            await asyncio.sleep(1)
        except asyncio.exceptions.CancelledError:
            break
```

## Example in GitHub

Refer to the [server-sent events example](https://github.com/Neoteroi/BlackSheep-Examples/tree/main/server-sent-events) for an example that handles application shutdown and client
disconnections, and also presents a basic example in JavaScript to use SSE.

## Using SSE in older versions of BlackSheep

The following example illustrates how to use server-sent events in older
versions of the web framework.

```python

import asyncio
import json
from blacksheep import Application, Response, StreamedContent, get

app = Application()


@get("/events")
def events_handler(request):
    async def provider():
        i = 0
        while True:
            # TODO: implement way to detect if the process is stopping,
            # and if the request is still active,
            # use await request.is_disconnected() if available...
            obj = {"message": f"Hello World {i}"}
            yield b"data: " + json.dumps(obj).encode("utf8") + b"\r\n\r\n"
            i += 1

            try:
                await asyncio.sleep(1)
            except asyncio.CancelledError:
                pass

    return Response(
        200,
        headers=[(b"Cache-Control", b"no-cache"), (b"Connection", b"Keep-Alive")],
        content=StreamedContent(b"text/event-stream", provider),
    )

```

## Related technologies

Server-sent events are often related to WebSockets, which instead enable
bi-directional communication between a server and a client, and to
[long-polling](https://github.com/Neoteroi/BlackSheep-Examples/tree/main/long-polling),
which is often used as a fall-back when SSE or WebSockets are not supported.
