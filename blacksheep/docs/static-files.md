F# Serving static files

This page covers:

- [X] How to serve static files.
- [X] Options for static files.
- [X] Non-obvious features handled when serving static files.
- [X] How to serve a Single Page Application (SPA) that uses the HTML5 History API

---

To serve static files, use the method `app.serve_files` as in the following
example:

```python
from blacksheep import Application

app = Application()

# serve files contained in a "static" folder relative to the server cwd
app.serve_files("static")
```

The path can be a relative one compared to the application `cwd`, or an
absolute path.

When serving files this way, a match-all route ("*") is configured in the
application router for `GET` and `HEAD`, and files are read from the configured
folder upon web requests.


It is also possible to serve static files from sub-folders:

```python
app.serve_files("app/static")
```

To enable file discovery, add the `discovery=True` parameter. In such case,
requests for directories will generate an HTML response with a list of files:

```python
app.serve_files("app/static", discovery=True)
```

Serving static files from multiple folders is supported, using a different path
for each folder:

```python
app = Application()

# serve files contained in a "static" folder relative to the server cwd
app.serve_files("app/images", root_path="images")
app.serve_files("app/videos", root_path="videos")
```

### Route paths and folder names

By default, when you serve files from a folder, the folder name is **not**
included in the route at which files are served. For example, if you have a
file `test.txt` in your `static` directory and you use:

```python
app.serve_files("static")
```

the file will be accessible at `http://localhost/test.txt` (not
`http://localhost/static/test.txt`).

If you want the files to be accessible under a specific route path (such as
`/static/`), use the `root_path` parameter:

```python
app.serve_files("static", root_path="static")
```

With this configuration, `test.txt` will be accessible at `http://localhost/static/test.txt`.

### Serving single files

If you need to serve single files, it is possible to use the `file` function
like in the following example.

```python
from blacksheep import Application, get
from blacksheep.server.responses import file, ContentDispositionType


app = Application()


@get("/favicon.ico")
def favicon_icon():
    # Note: the file is read asynchronously and served in chunks,
    # even though this function itself is synchronous
    return file(
        "path-to-your/favicon.ico",  # ← local path
        "image/vnd.microsoft.icon",
        content_disposition=ContentDispositionType.INLINE,
    )
```

## File extensions

Only files with a configured extension are served to the client. By default,
only files with these extensions are served (case insensitive check):

```python
'.txt',
'.css',
'.js',
'.jpeg',
'.jpg',
'.html',
'.ico',
'.png',
'.woff',
'.woff2',
'.ttf',
'.eot',
'.svg',
'.mp4',
'.mp3',
'.webp',
'.webm'
```

To configure extensions, use the dedicated parameter:

```python
app.serve_files("static", extensions={'.foo', '.config'})
```

## Accept-Ranges and Range requests

Range requests are enabled and handled by default, meaning that BlackSheep
supports serving big files with the pause and resume feature, and serving
videos and audio files with the possibility to jump to specific points.

## ETag and If-None-Match

`ETag`, `If-None-Match` and `HTTP Status 304 Not Modified` responses are
handled automatically, as well as support for `HEAD` requests returning only
headers with information about the files.

## Configurable Cache-Control

To control `Cache-Control` `max-age` HTTP header, use `cache_time` parameter,
defaulting to 10800 seconds (3 hours).

```python
app.serve_files("static", cache_time=90000)
```

## How to serve SPAs that use HTML5 History API

To serve an SPA that uses the HTML5 History API, configure a
`fallback_document="index.html"` if the index file is called "index.html".

```python {hl_lines="7"}
from blacksheep import Application

app = Application()

app.serve_files(
    "app/static",
    fallback_document="index.html",
)
```

If the SPA uses a file with a different name, specify both the index file name
and the fallback document to be the same:


```python {hl_lines="7-8"}
from blacksheep import Application

app = Application()

app.serve_files(
    "app/static",
    index_document="example.html",
    fallback_document="example.html",
)
```
