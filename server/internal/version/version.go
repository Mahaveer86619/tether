package version

// Version is overridden at build time with -ldflags "-X .../version.Version=...".
var Version = "dev"
