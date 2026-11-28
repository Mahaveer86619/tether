# Release tasks for the hub's machine (Linux). See docs/operations/releasing.md.
#   make test      vet and test the server, analyze and test the app
#   make dist      build dist/<version>: Go binaries, the signed APK, latest.json
#   make deploy    install a core dist here, with backup and rollback
#   make release-core / release-app   release one track from what is on main
#   make release-check TRACK=app      what that release would do; changes nothing
#   make release-prepare TRACK=app ...  open the version bump pull request
#   make release-local    test, build and deploy here without GitHub: the manual path
#   make ship      from another machine: build here, deploy over ssh (ARGS=--patch)
VERSION := $(shell tr -d ' \r\n' < VERSION)
TRACK ?= core

.PHONY: test test-go test-app dist dist-core dist-app deploy release release-core release-app release-check release-prepare release-status release-local release-test ship version

version:
	@tools/release/version.sh check

test: test-go test-app

test-go:
	cd server && go vet ./... && go test ./...

test-app:
	cd app && flutter analyze && flutter test --exclude-tags live

dist:
	tools/release/build.sh

# One track at a time, without the manifest (CI writes it after adding the Windows app).
dist-core:
	tools/release/build.sh core --no-manifest

dist-app:
	tools/release/build.sh app --no-manifest

# Without the APK, when only the server changed.
dist-go:
	tools/release/build.sh --no-android

deploy:
	deploy/linux/deploy.sh dist/$(VERSION)

release-local: test dist deploy

# The release flow, after the pull requests that belong in it are reviewed and merged (by hand).
# See docs/operations/releasing.md.
release: release-$(TRACK)

release-core:
	tools/release/release.sh core run

release-app:
	tools/release/release.sh app run

release-check:
	tools/release/release.sh $(TRACK) check

release-status:
	tools/release/release.sh $(TRACK) status

# make release-prepare TRACK=app BUMP=patch NOTES=notes.md
release-prepare:
	@test -n "$(BUMP)" -a -n "$(NOTES)" || { echo "usage: make release-prepare TRACK=core|app BUMP=patch|minor|major|X.Y.Z NOTES=file-with-changelog-bullets"; exit 2; }
	tools/release/release.sh $(TRACK) prepare $(BUMP) --notes $(NOTES)

release-test:
	tools/release/release_test.sh

# From your own machine, not the hub's: build and deploy over ssh. See docs/operations/releasing.md.
ship:
	tools/release/ship.sh $(ARGS)
