# Release tasks for the hub's machine (Linux). See docs/releasing.md.
#   make test      vet and test the server, analyze and test the app
#   make dist      build dist/<version>: Go binaries, the signed APK, latest.json
#   make deploy    install dist/<version> here, with backup and rollback
#   make release   all three, without GitHub: the manual path
VERSION := $(shell tr -d ' \r\n' < VERSION)

.PHONY: test test-go test-app dist dist-go deploy release version

version:
	@tools/release/version.sh check

test: test-go test-app

test-go:
	cd server && go vet ./... && go test ./...

test-app:
	cd app && flutter analyze && flutter test --exclude-tags live

dist:
	tools/release/build.sh

# Without the APK, when only the server changed.
dist-go:
	tools/release/build.sh --no-android

deploy:
	deploy/linux/deploy.sh dist/$(VERSION)

release: test dist deploy
