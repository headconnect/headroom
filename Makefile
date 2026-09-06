.PHONY: build test app run install release clean

build:
	swift build

test:
	swift run HeadroomChecks

app:
	scripts/bundle.sh

run: app
	open build/headroom.app

release:
	scripts/release.sh

install: app
	rm -rf /Applications/headroom.app
	cp -R build/headroom.app /Applications/

clean:
	rm -rf .build build
