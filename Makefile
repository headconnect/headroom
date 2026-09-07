.PHONY: build test app run install release artwork clean

build:
	swift build

test:
	swift run RangeAnxietyChecks

app:
	scripts/bundle.sh

run: app
	open "build/Range Anxiety.app"

release:
	scripts/release.sh

artwork:
	scripts/artwork.sh

install: app
	rm -rf "/Applications/Range Anxiety.app"
	cp -R "build/Range Anxiety.app" /Applications/

clean:
	rm -rf .build build
