.PHONY: build test app run install release artwork clean

build:
	swift build

test:
	swift run RationsChecks

app:
	scripts/bundle.sh

run: app
	open "build/Rations.app"

release:
	scripts/release.sh

artwork:
	scripts/artwork.sh

install: app
	rm -rf "/Applications/Rations.app"
	cp -R "build/Rations.app" /Applications/

clean:
	rm -rf .build build
