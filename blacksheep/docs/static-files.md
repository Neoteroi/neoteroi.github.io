# Serving static files

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

Enable file discovery (in such case, requests for directories will generate an
HTML response with a list of files):

```python
app.serve_files("app/static", discovery=True)
```

BlackSheep also supports serving static files from multiple folders, and
specifying a prefix for the route path:

```python
app = Application()

# serve files contained in a "static" folder relative to the server cwd
app.serve_files("app/images", root_path="images")
app.serve_files("app/videos", root_path="videos")
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
Range requests are enabled and handled by default (since version `0.2.1`),
meaning that BlackSheep supports serving big files with the pause and resume
feature, and serving videos with the possibility to jump to specific points.

## ETag and If-None-Match
`ETag`, `If-None-Match` and HTTP Status 304 Not Modified are handled
automatically, as well as support for `HEAD` requests returning only headers
with information about the files.

## Configurable Cache-Control
To control `Cache-Control` `max-age` HTTP header, use `cache_time` parameter
(defaults to 10800 seconds).

```python
app.serve_files("static", cache_time=90000)
```

## How to serve SPAs that use HTML5 History API

To serve an SPA that uses HTML5 History API, configure files serving with a
`fallback_document="index.html"` if the index file is called "index.html" (like
it happens in most scenarios).

```python
from blacksheep import Application

app = Application()

app.serve_files(
    "/path/to/folder/containing/spa",
    fallback_document="index.html",
)
```

If the SPA uses a file with a different name, specify both the index file name
and the fallback document to be the same:


```python
from blacksheep import Application

app = Application()

app.serve_files(
    "/path/to/folder/containing/spa",
    index_document="example.html",
    fallback_document="example.html",
)
```
