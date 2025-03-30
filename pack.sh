#! /bin/bash
folders=( blacksheep
          mkdocs-plugins
)

rm -rf site
rm -rf ./site.zip
mkdir -p site

for folder in "${folders[@]}" ; do
    echo "$folder 🏗️"
    mkdir site/$folder

    cd $folder

    mkdocs build

    mv site/* ../site/$folder
    rm -rf site
    cd ../
done

# The home is special...
echo "home"
cd home
mkdocs build
mv site/* ../site/
rm -rf site
cd ../

echo "Zipping..."
7z a -r site.zip site

echo "All done! ✨ 🍰 ✨"
