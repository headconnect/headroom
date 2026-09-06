.PHONY: build test app run install clean

build:
	swift build

test:
	swift run UsageWidgetChecks

app:
	scripts/bundle.sh

run: app
	open build/UsageWidget.app

install: app
	rm -rf /Applications/UsageWidget.app
	cp -R build/UsageWidget.app /Applications/

clean:
	rm -rf .build build
