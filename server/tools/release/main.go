// Command release writes a track's release manifest and checksums from the
// files in its dist folder. Run from server/:
//
//	go run ./tools/release -track core -dist ../dist/0.21.0 -version 0.21.0 \
//	  -base-url https://github.com/OWNER/tether/releases/download/core-v0.21.0 \
//	  -notes ../CHANGELOG.md -min-supported 0.15.0 -min-app 0.15.0
//
// See docs/operations/releasing.md.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

type asset struct {
	Name   string `json:"name"`
	URL    string `json:"url"`
	Sha256 string `json:"sha256"`
	Size   int64  `json:"size"`
}

type manifest struct {
	Version        string            `json:"version"`
	Notes          string            `json:"notes"`
	Published      string            `json:"published"`
	MinSupported   string            `json:"min_supported"`
	Platforms      map[string]*asset `json:"platforms"`
	Track          string            `json:"track,omitempty"`
	MinAppVersion  string            `json:"min_app_version,omitempty"`
	MinCoreVersion string            `json:"min_core_version,omitempty"`
}

type options struct {
	track   string
	minApp  string
	minCore string
}

func main() {
	dist := flag.String("dist", "", "the release's dist folder")
	version := flag.String("version", "", "the release version, e.g. 0.21.0")
	baseURL := flag.String("base-url", "", "where the files will be downloadable from, without a trailing slash")
	notes := flag.String("notes", "", "CHANGELOG.md; the section for this version becomes the notes")
	minSupported := flag.String("min-supported", "", "the oldest app and agent version that may keep running")
	track := flag.String("track", "", "release track: core or app")
	minApp := flag.String("min-app", "", "core feed: the oldest compatible app version")
	minCore := flag.String("min-core", "", "app feed: the required hub/core version")
	flag.Parse()
	if *dist == "" || *version == "" || *baseURL == "" {
		fmt.Fprintln(os.Stderr, "usage: release -track core|app -dist DIR -version X.Y.Z -base-url URL [-notes CHANGELOG.md] [-min-supported X.Y.Z] [-min-app X.Y.Z] [-min-core X.Y.Z]")
		os.Exit(2)
	}
	if *track != "" && *track != "core" && *track != "app" {
		fmt.Fprintln(os.Stderr, "release: track must be core or app")
		os.Exit(2)
	}
	opts := options{track: *track, minApp: *minApp, minCore: *minCore}
	if err := run(*dist, *version, strings.TrimRight(*baseURL, "/"), *notes, *minSupported, opts); err != nil {
		fmt.Fprintln(os.Stderr, "release:", err)
		os.Exit(1)
	}
}

func run(dist, version, baseURL, notesFile, minSupported string, opts options) error {
	entries, err := os.ReadDir(dist)
	if err != nil {
		return err
	}
	m := manifest{
		Version: version, MinSupported: minSupported, Published: time.Now().UTC().Format(time.RFC3339),
		Platforms: map[string]*asset{}, Track: opts.track, MinAppVersion: opts.minApp, MinCoreVersion: opts.minCore,
	}
	var sums []string
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || isFeedFile(name) {
			continue
		}
		sum, size, err := hashFile(filepath.Join(dist, name))
		if err != nil {
			return err
		}
		sums = append(sums, sum+"  "+name)
		if key := platformOf(name, version, opts.track); key != "" {
			m.Platforms[key] = &asset{Name: name, URL: baseURL + "/" + name, Sha256: sum, Size: size}
		}
	}
	if len(m.Platforms) == 0 {
		return fmt.Errorf("no %s release files in %s", trackLabel(opts.track), dist)
	}
	if notesFile != "" {
		b, err := os.ReadFile(notesFile)
		if err != nil {
			return err
		}
		m.Notes = notesFor(string(b), version)
	}
	sort.Strings(sums)
	b, _ := json.MarshalIndent(m, "", "  ")
	sumFile := "SHA256SUMS"
	manifestFile := "latest.json"
	if opts.track != "" {
		sumFile = opts.track + "-SHA256SUMS"
		manifestFile = opts.track + "-latest.json"
	}
	for _, name := range []string{sumFile, "SHA256SUMS"} {
		if err := os.WriteFile(filepath.Join(dist, name), []byte(strings.Join(sums, "\n")+"\n"), 0o644); err != nil {
			return err
		}
	}
	for _, name := range []string{manifestFile, "latest.json"} {
		if err := os.WriteFile(filepath.Join(dist, name), append(b, '\n'), 0o644); err != nil {
			return err
		}
	}
	return nil
}

func isFeedFile(name string) bool {
	return name == "latest.json" || name == "SHA256SUMS" || strings.HasSuffix(name, "-latest.json") || strings.HasSuffix(name, "-SHA256SUMS")
}

func trackLabel(track string) string {
	if track == "" {
		return "unified"
	}
	return track
}

// platformOf maps a dist file name to its key in a track's manifest. A core
// dist must not contain app files, and an app dist must not contain core files;
// the empty track is the old unified release, which carries both.
func platformOf(name, version, track string) string {
	if track == "app" || track == "" {
		switch name {
		case "tether-" + version + ".apk":
			return "android"
		case "tether-windows-" + version + ".zip":
			return "windows"
		}
	}
	if track == "core" || track == "" {
		for _, bin := range []string{"tether-hub", "tether-agent", "tetherctl", "tether-herdr"} {
			for _, osArch := range []string{"linux-amd64", "windows-amd64"} {
				file := bin + "-" + osArch
				if strings.HasPrefix(osArch, "windows") {
					file += ".exe"
				}
				if name == file {
					return strings.TrimPrefix(bin, "tether-") + "-" + osArch
				}
			}
		}
	}
	return ""
}

// notesFor is the CHANGELOG.md section headed "## <version>" (with or
// without a leading v and a trailing date).
func notesFor(changelog, version string) string {
	head := regexp.MustCompile(`(?m)^## v?` + regexp.QuoteMeta(version) + `\b.*$`)
	loc := head.FindStringIndex(changelog)
	if loc == nil {
		return ""
	}
	rest := changelog[loc[1]:]
	if next := regexp.MustCompile(`(?m)^## `).FindStringIndex(rest); next != nil {
		rest = rest[:next[0]]
	}
	return strings.TrimSpace(rest)
}

func hashFile(path string) (string, int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", 0, err
	}
	defer f.Close()
	h := sha256.New()
	n, err := io.Copy(h, f)
	return hex.EncodeToString(h.Sum(nil)), n, err
}
