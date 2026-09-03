.PHONY: build run app install clean

# Debug build + run straight from the CLI (no bundle, login-item disabled).
run:
	swift run

build:
	swift build -c release

# Package dist/DeskNudge.app
app:
	./scripts/bundle.sh

# Build and copy into /Applications
install: app
	rm -rf /Applications/DeskNudge.app
	cp -R dist/DeskNudge.app /Applications/
	@echo "Installed to /Applications/DeskNudge.app"
	open /Applications/DeskNudge.app

clean:
	rm -rf .build dist
