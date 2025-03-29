BlackSheep implements built-in features to handle automatic response
compression. This page describes:

- [X] How to use the `GzipMiddleware` to enable gzip compression


## GzipMiddleware

To enable automatic compression of response bodies using `gzip`, use the
`GzipMiddleware` like in the following example:

```python
from blacksheep import Application
from blacksheep.server.compression import GzipMiddleware


app = Application()


app.middlewares.append(GzipMiddleware())
```

Or, in alternative:

```python
from blacksheep import Application
from blacksheep.server.compression import use_gzip_compression


app = Application()


use_gzip_compression(app)
```

!!! warning "Not for streamed content"
    The `GzipMiddleware` does not compress bytes streamed using the
    `StreamedContent` class (used by default when serving files), it only
    compresses whole bodies like, for example, those that are generated when
    returning `JSON` content to the client.

### Options

The following table describes options for the `GzipMiddleware` constructor.

| Option        | Type                                  | Description                                                                                                                                              |
| ------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| min_size      | `int` (default 500)                   | The minimum size before applying compression to response bodies.                                                                                         |
| comp_level    | `int` (default 5)                     | The compression level, as passed to `gzip.compress` function.                                                                                            |
| handled_types | `Optional[Iterable[bytes]]`           | Control which content types can be compressed by the specific instance of `GzipMiddleware`.                                                              |
| executor      | `Optional[Executor]` (default `None`) | Control which instance of `concurrent.future.Executor` is used to compress - if not specified the default executor handled by `run_in_executor` is used. |

When `handled_types` is not specified for an instance of `GzipMiddleware`,
compression is applied by default to content types containing any of the
following strings:

- _json_
- _xml_
- _yaml_
- _html_
- _text/plain_
- _application/javascript_
- _text/css_
- _text/csv_
