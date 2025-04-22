# ASGI Servers

BlackSheep is an [ASGI](https://asgi.readthedocs.io/en/latest/) web framework,
which requires an ASGI HTTP server to run, such as
[Uvicorn](http://www.uvicorn.org/), or
[Hypercorn](https://pgjones.gitlab.io/hypercorn/). All examples in this
documentation use `Uvicorn`, but the framework has also been tested with
Hypercorn and should work with any server that implements the `ASGI`
specification.

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
  <a href="https://github.com/pgjones/hypercorn"><img width="270" src="https://raw.githubusercontent.com/pgjones/hypercorn/main/artwork/logo.png" alt="Hypercorn"></a>
</p>

---

Many details, such as how to run the server in production, depend on the chosen
ASGI server.
