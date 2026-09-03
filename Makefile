.PHONY: build run app install clean

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
