# For the maintainer having the necessary rights to publish from the local
# dev environment...

if [[ ! -d "site" ]]; then
    echo -e "\033[31mError: 'site' folder does not exist. Aborting.\033[0m"
    exit 1
fi

read -p "Are you sure you want to proceed? (y/n): " confirmation

if [[ "$confirmation" =~ ^[Yy]$ ]]; then
    echo "Deploying..."

    rm -rf deploy
    mkdir deploy
    cd deploy

    git clone -b gh-pages git@github.com:Neoteroi/neoteroi.github.io.git copy

    cp copy/CNAME ../site/
    cp copy/README.md ../site/

    rm -rf copy/*
    cp -r ../site/* copy/

    cd copy/
    git add .
    git commit -m "Deploy documentation on $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    git push origin gh-pages --force

    echo "Published to gh-pages"
else
    echo "Operation canceled."
    exit 1
fi
