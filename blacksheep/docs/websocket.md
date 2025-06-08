# WebSocket

**WebSocket** is a technology that enables the creation of a persistent,
bi-directional connection between a client and a server. It is commonly used in
real-time applications, such as chat apps and similar use cases.

BlackSheep can handle incoming WebSocket connections when used with an ASGI
server that supports the WebSocket protocol (e.g.,
[Uvicorn](https://www.uvicorn.org/#quickstart),
[Hypercorn](https://pgjones.gitlab.io/hypercorn/) or
[Granian](https://github.com/emmett-framework/granian)).

## Creating a WebSocket route

To make your request handler function as a WebSocket handler, use the `ws`
decorator or the corresponding `add_ws` method provided by the app router. Note
that the `ws` decorator does not have a default path pattern, so you must
specify one.

Route parameters can be used in the same way as with regular request handlers.


=== "Using `ws` decorator"

    ```py
    from blacksheep import Application, WebSocket, ws

    app = Application()


    @ws("/ws/{client_id}")
    async def ws_handler(websocket: WebSocket, client_id: str):
        ...
    ```

=== "Using `add_ws` method"

    ```py
    from blacksheep import Application, WebSocket

    app = Application()


    async def ws_handler(websocket: WebSocket, client_id: str):
        ...


    app.router.add_ws("/ws/{client_id}", ws_handler)
    ```

When a client attempts to connect to the endpoint, a `WebSocket` object is
bound to a parameter and injected into your handler function.

/// admonition | Required function signature.
    type: danger

Make sure that your function either has a parameter named **websocket** or
a parameter type annotated with the `WebSocket` class.
Otherwise, the route will not function properly.

///

## Accepting the connection

The `WebSocket` class provides the `accept` method to accept a connection,
allowing you to pass optional parameters to the client. These parameters
include **headers**, which are sent back to the client with the handshake response,
and **subprotocol**, which specifies the protocol your application agrees to use.

/// admonition | For more information.

The [MDN article](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers)
on writing WebSocket servers has some additional information regarding
subprotocols and response headers.

///


```python
@ws("/ws")
async def ws_handler(websocket: WebSocket):
    # Parameters are optional.
    await websocket.accept(
        headers=[(b"x-custom-header", b"custom-value")],
        subprotocol="custom-protocol"
    )
```

As soon as the connection is accepted, you can start receiving and sending
messages.

## Communicating with the client

There are three pairs of helper method for communicating with the client:
`receive_text`/`send_text`, `receive_bytes`/`send_bytes` and
`receive_json`/`send_json`.

There is also the `receive` method that allows for receiving raw WebSocket
messages. However, in most cases, you will want to use one of the helper
methods.

All send methods accept an argument of data to be sent.
`receive_json`/`send_json` also accepts a **mode** argument. It defaults to
`MessageMode.TEXT` and can be set to `MessageMode.BYTES` if, for example, your
client sends you encoded JSON strings.

Below is a simple example of an echo WebSocket handler.

This function will receive a text message sent by the client and echo it back
until either the client disconnects or the server shuts down.


=== "Text"

    ```py
    @ws("/ws")
    async def echo(websocket: WebSocket):
        await websocket.accept()

        while True:
            msg = await websocket.receive_text()
            # "Hello world!"
            await websocket.send_text(msg)
    ```

=== "Bytes"

    ```py
    @ws("/ws")
    async def echo(websocket: WebSocket):
        await websocket.accept()

        while True:
            msg = await websocket.receive_bytes()
            # b"Hello world"
            await websocket.send_bytes(msg)
    ```

=== "JSON"

    ```py
    @ws("/ws")
    async def echo(websocket: WebSocket):
        await websocket.accept()

        while True:
            msg = await websocket.receive_json()
            # {'msg': 'Hello world!'}
            await websocket.send_json(msg)
    ```

## Handling client disconnect

If a client disconnects, the `ASGI` server will close the connection and send a corresponding message to your application. When this message is received, the `WebSocket` object raises the `WebSocketDisconnectError` exception.

You'll likely want to catch it and handle it somehow.

```py
from blacksheep import WebSocket, WebSocketDisconnectError, ws

...

@ws("/ws")
async def echo(websocket: WebSocket):
    await websocket.accept()

    try:
        while True:
            msg = await websocket.receive_text()
            await websocket.send_text(msg)
    except WebSocketDisconnectError:
        ... # Handle the disconnect.
```

## Example: chat application

[Here](https://github.com/Neoteroi/BlackSheep-Examples/tree/main/websocket-chat)
you can find a basic example app using BlackSheep and VueJS.
