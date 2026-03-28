# Requests

This page describes:

- [X] Handling requests.
- [X] Reading parameters from the request.
- [X] Reading request headers and cookies.
- [X] Reading request bodies.

## The Request class

BlackSheep handles requests as instances of the `blacksheep.Request` class.
This class provides methods and properties to handle request headers, cookies,
the URL, route parameters, the request body, the user's identity, and other
information like the content type of the request. Each web request results in
the creation of a new instance of `Request`.

### Reading parameters from the request object

It is possible to read query and route parameters from an instance of
`request`. The example below shows how the query string, route parameters, and
request headers can be read from the request:

```python
from blacksheep import Application, Request, Response, get, text


app = Application()


@get("/{something}")
def example(request: Request) -> Response:
    client_accept = request.headers.get_first(b"Accept")
    # client_accept is None or bytes

    hello = request.query.get("hello")
    # hello is None or a List[str]

    something = request.route_values["something"]
    # something is str

    return text(
        f"""
        Accept: {client_accept.decode()}
        Hello: {hello}
        Something: {something}
        """
    )
```

However, the recommended approach is to use automatic bindings, which enable a
more accurate generation of OpenAPI Documentation, automatic parsing of values
into the desired type, and improves the development experience and source code.

The same example can be achieved in the following way:

```python
from blacksheep import Application, Request, Response, get, text, FromHeader, FromQuery


app = Application()


class FromAcceptHeader(FromHeader[str]):
    name = "Accept"


@get("/{something}")
def example(
    something: str, accept: FromAcceptHeader, hello: FromQuery[str]
) -> Response:
    return text(
        f"""
        Accept: {accept.value}
        Hello: {hello.value}
        Something: {something}
        """
    )

```

HTTP GET `/example?hello=World`:
```
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,mage/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9
Hello: World
Something: example
```

### Reading request headers and cookies

```python
from typing import Optional

from blacksheep import Application, Response, get, text, FromHeader, FromCookie

app = Application()


class FromAcceptHeader(FromHeader[str]):
    name = "Accept"


class FromFooCookie(FromCookie[str | None]):
    name = "foo"


@get("/")
def home(accept: FromAcceptHeader, foo: FromFooCookie) -> Response:
    return text(
        f"""
        Accept: {accept.value}
        Foo: {foo.value}
        """
    )
```

### Reading the request body

The request class offers several methods to read request bodies of different
kinds.

#### Reading JSON

===  "Using binders (recommended)"

    ```python
    from dataclasses import dataclass

    from blacksheep import FromJSON, post


    @dataclass
    class SomethingInput:
        name: str
        foo: bool


    @post("/something")
    async def create_something(input: FromJSON[SomethingInput]):
        data = input.value

        # data is already deserialized from JSON into an instance of
        # `SomethingInput`
    ```

    The type parameter for the `FromJSON` binder can be a dataclass, a model from
    [`pydantic`](https://github.com/samuelcolvin/pydantic), or a regular class
    with an `__init__` method.

    Note that when mapping the request's payload to an instance of the desired
    type, the type's constructor with `cls(**data)` is used. If it necessary to
    parse dates or other complex types this must be done in the constructor of the
    class. To gracefully handle a payload with extra properties, use `*args` in
    your class constructor: `__init__(one, two, three, *args)`.

    To read the JSON payload as a regular dictionary, use `dict` as the type
    argument:

    ```python
    @post("/something")
    async def create_something(input: FromJSON[dict]):
        ...
    ```

=== "Directly from the request"

    When the JSON is read from the request object, it is always treated as
    the raw deserialized object (usually a dictionary or a list).

    ```python
    @post("/something")
    async def create_something(request: Request):
        data = await request.json()

        # data is the deserialized object
    ```

#### Reading a form request body

/// admonition | Improved in BlackSheep 2.6.0
    type: info

Starting from BlackSheep 2.6.0, `request.form()` and `request.multipart()` use `SpooledTemporaryFile` for memory-efficient file handling. Small files (<1MB) are kept in memory, while larger files automatically spill to temporary disk files. The framework automatically cleans up resources at the end of each request.

///

===  "Using binders (recommended)"

    ```python
    from blacksheep import FromForm, post


    class SomethingInput:
        name: str
        foo: bool

        def __init__(self, name: str, foo: str) -> None:
            self.name = name
            self.foo = bool(foo)


    @post("/something")
    async def create_something(input: FromForm[SomethingInput]):
        data = input.value

        # data is already deserialized from the form body into an instance
        # of `SomethingInput` - however some properties need to be parsed
        # from str into the desired type in the class definition -
        # see __init__ above
    ```


=== "Directly from the request"

    ```python
    @post("/something")
    async def create_something(request: Request):
        data = await request.form()

        # data is a dictionary
    ```

#### Reading text

===  "Using binders (recommended)"

    ```python
    from blacksheep import FromText


    @post("/something")
    async def store_text(text: FromText):
        data = text.value
    ```

=== "Directly from the request"

    ```python
    @post("/text")
    async def create_text(request: Request):
        data = await request.text()

        # data is a string
    ```

#### Reading raw bytes

===  "Using binders (recommended)"

    ```python
    from blacksheep import FromBytes


    @post("/something")
    async def example(payload: FromBytes):
        data = payload.value
    ```

=== "Directly from the request"

    ```python
    @post("/text")
    async def example(request: Request):
        data = await request.read()

        # data is bytes
    ```

#### Reading files and multipart/form-data

/// admonition | Significantly improved in BlackSheep 2.6.0
    type: info

BlackSheep 2.6.0 introduces significant improvements for handling `multipart/form-data` with memory-efficient streaming and file handling:

- **Memory-efficient file handling**: Files use `SpooledTemporaryFile` - small files (<1MB) stay in memory, larger files automatically spill to temporary disk files
- **True streaming parsing**: New `Request.multipart_stream()` method for streaming multipart data without buffering the entire request body
- **Automatic resource cleanup**: The framework automatically calls `Request.dispose()` at the end of each request to clean up file resources
- **Better API**: `FileBuffer` class provides clean methods (`read()`, `seek()`, `close()`, `save_to()`) for uploaded files
- **Streaming parts**: `FormPart.stream()` method to stream part data in chunks
- **OpenAPI support**: `FromText` and `FromFiles` are now properly documented in OpenAPI

///

Files are read from `multipart/form-data` payload.

===  "Using binders (recommended)"

    ```python
    from blacksheep import FromFiles, post


    @post("/upload")
    async def post_files(files: FromFiles):
        # files.value is a list of FormPart objects
        for file_part in files.value:
            # Access file metadata
            file_name = file_part.file_name.decode() if file_part.file_name else "unknown"
            content_type = file_part.content_type.decode() if file_part.content_type else None
            
            # file_part.file is a FileBuffer instance with efficient memory handling
            # Small files (<1MB) are kept in memory, larger files use temporary disk files
            file_buffer = file_part.file
            
            # Read file content
            content = file_buffer.read()
            
            # Or save directly to disk
            await file_buffer.save_to(f"./uploads/{file_name}")
    ```

=== "Directly from the request"

    ```python
    from blacksheep import post, Request


    @post("/upload-files")
    async def upload_files(request: Request):
        files = await request.files()

        for part in files:
            # Access file metadata
            file_name = part.file_name.decode() if part.file_name else "unknown"
            
            # file_bytes contains the entire file content
            file_bytes = part.data
            
            # Or use the FileBuffer for more control
            file_buffer = part.file
            content = file_buffer.read()
    ```

=== "Memory-efficient streaming (2.6.0+)"

    For handling large file uploads efficiently without loading the entire request body into memory:

    ```python
    from blacksheep import post, Request, created


    @post("/upload-large")
    async def upload_large_files(request: Request):
        # Stream multipart data without buffering entire request body
        async for part in request.multipart_stream():
            if part.file_name:
                # This is a file upload
                file_name = part.file_name.decode()
                
                # Stream the file content in chunks
                with open(f"./uploads/{file_name}", "wb") as f:
                    async for chunk in part.stream():
                        f.write(chunk)
            else:
                # This is a regular form field
                field_name = part.name.decode() if part.name else ""
                field_value = part.data.decode()
                print(f"Field {field_name}: {field_value}")
        
        return created()
    ```

=== "Mixed form with files and text (2.6.0+)"

    Using `FromFiles` and `FromText` together in the same handler:

    ```python
    from blacksheep import FromFiles, FromText, post


    @post("/upload-with-description")
    async def upload_with_metadata(
        description: FromText,
        files: FromFiles,
    ):
        # description.value contains the text field value
        text_content = description.value
        
        # files.value contains the uploaded files
        for file_part in files.value:
            file_name = file_part.file_name.decode() if file_part.file_name else "unknown"
            
            # Process the file
            await file_part.file.save_to(f"./uploads/{file_name}")
        
        return {"description": text_content, "files_count": len(files.value)}
    ```

##### Resource management and cleanup

BlackSheep automatically manages file resources. The framework calls `Request.dispose()` at the end of each request-response cycle to clean up temporary files. However, if you need manual control:

```python
from blacksheep import post, Request


@post("/manual-cleanup")
async def manual_file_handling(request: Request):
    try:
        files = await request.files()
        
        for part in files:
            # Process files
            pass
    finally:
        # Manually clean up resources if needed
        # (normally not required as framework does this automatically)
        request.dispose()
```

##### FileBuffer API

The `FileBuffer` class wraps `SpooledTemporaryFile` and provides these methods:

- `read(size: int = -1) -> bytes`: Read file content
- `seek(offset: int, whence: int = 0) -> int`: Change file position
- `close() -> None`: Close the file
- `async save_to(file_path: str) -> None`: Asynchronously save file to disk (must be awaited)

```python
from blacksheep import FromFiles, post


@post("/process-file")
async def process_file(files: FromFiles):
    for file_part in files.value:
        file_buffer = file_part.file
        
        # Read first 100 bytes
        header = file_buffer.read(100)
        
        # Go back to start
        file_buffer.seek(0)
        
        # Read entire content
        full_content = file_buffer.read()
        
        # Save to disk
        await file_buffer.save_to("./output.bin")
```

#### Reading streams

Reading streams enables reading large-sized bodies using an asynchronous
generator. The example below saves a file of arbitrary size without blocking
the event loop:

=== "Directly from the request"

    ```python
    from blacksheep import created, post


    @post("/upload")
    async def save_big_file(request: Request):

        with open("./data/0001.dat", mode="wb") as saved_file:
            async for chunk in request.stream():
                saved_file.write(chunk)

        return created()
    ```
