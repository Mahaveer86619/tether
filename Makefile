# Release tasks for the hub's machine (Linux). See docs/operations/releasing.md.
#   make test      vet and test the server, analyze and test the app
#   make dist      build dist/<version>: Go binaries, the signed APK, latest.json
#   make deploy    install dist/<version> here, with backup and rollback
#   make release   release what is on main: tag it, watch GitHub build and deploy it, check it
#   make release-check    what make release would do; changes nothing
#   make release-prepare  open the pull request that bumps the version (BUMP=patch NOTES=file)
#   make release-status   the newest release and the hub's version
#   make release-local    test, build and deploy here without GitHub: the manual path
#   make ship      from another machine: build here, deploy over ssh (ARGS=--patch)
VERSION := $(shell tr -d ' \r\n' < VERSION)

.PHONY: test test-go test-app dist dist-go deploy release release-check release-prepare release-status release-local release-test ship version

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

release-local: test dist deploy

# The release flow, after the pull requests that belong in it are reviewed and merged (by hand).
# See docs/operations/releasing.md.
release:
	tools/release/release.sh

release-check:
	tools/release/release.sh check

release-status:
	tools/release/release.sh status

# make release-prepare BUMP=patch NOTES=notes.md   (BUMP is patch, minor, major or X.Y.Z)
release-prepare:
	@test -n "$(BUMP)" -a -n "$(NOTES)" || { echo "usage: make release-prepare BUMP=patch|minor|major|X.Y.Z NOTES=file-with-changelog-bullets"; exit 2; }
	tools/release/release.sh prepare $(BUMP) --notes $(NOTES)

release-test:
	tools/release/release_test.sh

# From your own machine, not the hub's: build and deploy over ssh. See docs/operations/releasing.md.
ship:
	tools/release/ship.sh $(ARGS)
