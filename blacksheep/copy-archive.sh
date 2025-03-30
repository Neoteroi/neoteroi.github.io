#! /bin/bash

# This file expects an existing ./site folder created using MkDocs build.
# It unzips archives of older versions of the documentation into the site
# folder.
7z x -o"site/v1" archive/v1.7z
