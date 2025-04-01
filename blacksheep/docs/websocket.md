# WebSocket

**WebSocket** is a technology that allows creating a persistent, bi-directional
connection between a client and a server. It's mostly used in real-time apps,
chat apps, etc.

BlackSheep is able to handle incoming WebSocket connections if you're using
an ASGI server that supports WebSocket protocol
(for example [Uvicorn](https://www.uvicorn.org/#quickstart)
or [Hypercorn](https://pgjones.gitlab.io/hypercorn/)).

## Creating a WebSocket route

If you want your request handler to act as a WebSocket handler, use the `ws`
decorator or a corresponding `add_ws` method provided by the app router. Note
that the `ws` decorator doesn't have a default path pattern, so you must pass
it.

You can use route parameters just like with the regular request handlers.


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

A `WebSocket` object will be bound to a parameter injected into your handler
function when the client tries to connect to the endpoint.

!!! warning "Be careful"
    Make sure that your function either has a parameter named **websocket** or
    a parameter with an arbitrary name, annotated with the `WebSocket` class.
    Otherwise, the route will not function properly.

## Accepting the connection

The `WebSocket` class provides the `accept` method to accept a connection,
passing optional parameters  to the client. These optional parameters are
**headers** which will be sent back to the client with the handshake response
and **subprotocol** that your application agrees to accept.

!!! info
    The [MDN article](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers)
    on writing WebSocket servers has some additional information regarding
    subprotocols and response headers.

```py
@ws("/ws")
async def ws_handler(websocket: WebSocket):
    # Parameters are optional.
    await websocket.accept(
        headers=[(b"x-custom-header", b"custom-value")],
        subprotocol="custom-protocol"
    )
```

As soon as the connection is accepted, you can start receiving and sending messages.

## Communicating with the client

There are 3 helper method pairs to communicate with the client:
`receive_text`/`send_text`, `receive_bytes`/`send_bytes` and
`receive_json`/`send_json`.

There is also the `receive` method that allows for receiving raw WebSocket
messages. Although most of the time you'll want to use one of the helper
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

In the event of a client disconnect, the ASGI server will close the connection
and send the corresponding message to your app. Upon receiving this message
`WebSocket` object will raise the `WebSocketDisconnectError` exception.

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
