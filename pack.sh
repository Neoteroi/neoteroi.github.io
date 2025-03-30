#! /bin/bash
folders=( blacksheep
          mkdocs-plugins
)

rm -rf site
mkdir -p site

for folder in "${folders[@]}" ; do
    echo "$folder"
    mkdir site/$folder

    cd $folder

    mkdocs build

    mv site/* ../site/$folder
    cd ../
done

# The home is special...
cd home
mkdocs build
mv site/* ../site/
cd ../

echo "Zipping..."
7z a -r site.zip site
