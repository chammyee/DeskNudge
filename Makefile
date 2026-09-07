.PHONY: build run app install clean release

# Debug build + run straight from the CLI (no bundle, login-item disabled).
run:
	swift run

build:
	swift build -c release

# Package dist/Notipop.app
app:
	./scripts/bundle.sh

# Build and copy into /Applications
install: app
	rm -rf /Applications/Notipop.app
	cp -R dist/Notipop.app /Applications/
	@echo "Installed to /Applications/Notipop.app"
	open /Applications/Notipop.app

clean:
	rm -rf .build dist

# Zip the app for a GitHub Release. Usage: make release VERSION=0.2.0
release: app
	@test -n "$(VERSION)" || (echo "usage: make release VERSION=0.2.0" && exit 1)
	mkdir -p dist/release
	ditto -c -k --keepParent dist/Notipop.app dist/release/Notipop-v$(VERSION).zip
	@echo
	@echo "→ dist/release/Notipop-v$(VERSION).zip"
	@echo "→ Draft a release at https://github.com/chammyee/DeskNudge/releases/new"
	@echo "  tag v$(VERSION), attach the zip, publish."
