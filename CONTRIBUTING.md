# Contributing to Tether

The full guide is [docs/getting-started/contributing.md](docs/getting-started/contributing.md). The short version:

1. Set up from a clone: [docs/getting-started/from-source.md](docs/getting-started/from-source.md).
2. Branch from `main`, make a focused change with a test, and update the doc it belongs to.
3. Run `make test` (Go vet and tests, Flutter analyze and tests).
4. Open a pull request against `main`.

Never run `dart format` on the app, and keep private addresses and hostnames out of committed files.
