#! /bin/bash
folders=( blacksheep
          mkdocs-plugins
)

for folder in "${folders[@]}" ; do
    echo "$folder"
    cd $folder
    mkdocs build
    cd ../
done
