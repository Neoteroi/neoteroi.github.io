#! /bin/bash
folders=(
    blacksheep
    rodi
    mkdocs-plugins
)

rm -rf site
rm -rf ./site.zip
mkdir -p site

for folder in "${folders[@]}" ; do
    echo "$folder 🏗️"
    mkdir site/$folder

    cd $folder

    GIT_CONTRIBS_ON=True mkdocs build

    # check if there is a copy-archive.sh file, to support including docs
    # of older versions of the library
    if [ -f "copy-archive.sh" ]; then
        echo "File $FILE exists."
        ./copy-archive.sh
    fi

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
