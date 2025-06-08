# ASGI Servers

BlackSheep is an [ASGI](https://asgi.readthedocs.io/en/latest/) web framework,
which requires an ASGI HTTP server to run, such as
[Uvicorn](http://www.uvicorn.org/), or
[Hypercorn](https://pgjones.gitlab.io/hypercorn/) or
[Granian](https://github.com/emmett-framework/granian). All examples in this
documentation use `Uvicorn`, but the framework has also been tested with
Hypercorn and should work with any server that implements the `ASGI`
specification.

### Uvicorn

<br />
<div class="img-auto-width"></div>
<p align="left">
  <a href="https://www.uvicorn.org"><img width="270" src="https://raw.githubusercontent.com/tomchristie/uvicorn/master/docs/uvicorn.png" alt="Uvicorn"></a>
</p>

### Granian

<br />
<div class="img-auto-width"></div>
<p align="left">
  <a href="https://github.com/emmett-framework/granian"><img width="330" src="https://camo.githubusercontent.com/cc0d9333c913fa2ce690b247909b1ab3e54c9a74b269bfc79e2e62c7a339b077/68747470733a2f2f656d6d6574742e73682f7374617469632f696d672f6772616e69616e2d6c6f676f2d78622d66772e706e67" alt="Granian"></a>
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
