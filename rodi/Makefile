.PHONY: build fixlinks
include .env

build:
	mkdocs build
	./fixlinks.sh
	rm -rf .build
	mkdir -p .build/blacksheep
	mv site/* .build/blacksheep
	echo "Ready to publish"


build-v1:
	mkdocs build
	VERSION="v1" ./fixlinks.sh
	rm -rf .build
	mkdir -p .build/blacksheep/v1
	mv site/* .build/blacksheep/v1
	echo "Ready to publish"


clean:
	rm -rf site/
	rm -rf .build/
