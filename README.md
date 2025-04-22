# Neoteroi documentation 📜

This repository contains the source code of the documentation that gets
published to [https://www.neoteroi.dev/](https://www.neoteroi.dev/).

## How to contribute

The documentation uses MkDocs and Material for MkDocs. For information on how
to use these tools, refer to their documentation.

```bash
$ mkdocs serve
```

## How to build the full site

- Create a Python virtual environment, activate, install the dependencies.
- Use `pack.sh` to build the full site.
- `cd` into the generated `site` folder.
- Start a dev servers. Recommended: use `Python http.server` module.

```bash
./pack.sh

cd site

python3.13 -m http.server 44777
```
