# ASGI Servers

BlackSheep belongs to the category of
[ASGI](https://asgi.readthedocs.io/en/latest/) web frameworks, so it requires
an ASGI HTTP server to run, such as [uvicorn](http://www.uvicorn.org/), or
[hypercorn](https://pgjones.gitlab.io/hypercorn/). All examples in this
documentation use `Uvicorn`, but the framework has been tested also with
`Hypercorn` and should work with any server that implements ASGI.

### Uvicorn

<br />
<div class="img-auto-width"></div>
<p align="left">
  <a href="https://www.uvicorn.org"><img width="270" src="https://raw.githubusercontent.com/tomchristie/uvicorn/master/docs/uvicorn.png" alt="Uvicorn"></a>
</p>

### Hypercorn

<br />
<div class="img-auto-width"></div>
<p align="left">
  <a href="https://pgjones.gitlab.io/hypercorn/"><img width="270" src="https://pgjones.gitlab.io/hypercorn/_images/logo.png" alt="Hypercorn"></a>
</p>

Many details, such as how to run the server in production, depend on the chosen
ASGI server.
