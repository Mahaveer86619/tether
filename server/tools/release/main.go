// Command release writes a release's latest.json and SHA256SUMS from the
// files in its dist folder. Run from server/:
//
//	go run ./tools/release -dist ../dist/0.17.0 -version 0.17.0 \
//	  -base-url https://github.com/OWNER/tether/releases/download/v0.17.0 \
//	  -notes ../CHANGELOG.md -min-supported 0.15.0
//
// See docs/releasing.md.
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
	Version      string            `json:"version"`
	Notes        string            `json:"notes"`
	Published    string            `json:"published"`
	MinSupported string            `json:"min_supported"`
	Platforms    map[string]*asset `json:"platforms"`
}

func main() {
	dist := flag.String("dist", "", "the release's dist folder")
	version := flag.String("version", "", "the release version, e.g. 0.17.0")
	baseURL := flag.String("base-url", "", "where the files will be downloadable from, without a trailing slash")
	notes := flag.String("notes", "", "CHANGELOG.md; the section for this version becomes the notes")
	minSupported := flag.String("min-supported", "", "the oldest app and agent version that may keep running")
	flag.Parse()
	if *dist == "" || *version == "" || *baseURL == "" {
		fmt.Fprintln(os.Stderr, "usage: release -dist DIR -version X.Y.Z -base-url URL [-notes CHANGELOG.md] [-min-supported X.Y.Z]")
		os.Exit(2)
	}
	if err := run(*dist, *version, strings.TrimRight(*baseURL, "/"), *notes, *minSupported); err != nil {
		fmt.Fprintln(os.Stderr, "release:", err)
		os.Exit(1)
	}
}

func run(dist, version, baseURL, notesFile, minSupported string) error {
	entries, err := os.ReadDir(dist)
	if err != nil {
		return err
	}
	m := manifest{Version: version, MinSupported: minSupported, Published: time.Now().UTC().Format(time.RFC3339), Platforms: map[string]*asset{}}
	var sums []string
	for _, e := range entries {
		name := e.Name()
		if e.IsDir() || name == "latest.json" || name == "SHA256SUMS" {
			continue
		}
		sum, size, err := hashFile(filepath.Join(dist, name))
		if err != nil {
			return err
		}
		sums = append(sums, sum+"  "+name)
		if key := platformOf(name, version); key != "" {
			m.Platforms[key] = &asset{Name: name, URL: baseURL + "/" + name, Sha256: sum, Size: size}
		}
	}
	if len(m.Platforms) == 0 {
		return fmt.Errorf("no release files in %s", dist)
	}
	if notesFile != "" {
		b, err := os.ReadFile(notesFile)
		if err != nil {
			return err
		}
		m.Notes = notesFor(string(b), version)
	}
	sort.Strings(sums)
	if err := os.WriteFile(filepath.Join(dist, "SHA256SUMS"), []byte(strings.Join(sums, "\n")+"\n"), 0o644); err != nil {
		return err
	}
	b, _ := json.MarshalIndent(m, "", "  ")
	return os.WriteFile(filepath.Join(dist, "latest.json"), append(b, '\n'), 0o644)
}

// platformOf maps a dist file name to its key in latest.json.
func platformOf(name, version string) string {
	switch {
	case name == "tether-"+version+".apk":
		return "android"
	case name == "tether-windows-"+version+".zip":
		return "windows"
	}
	for _, bin := range []string{"tether-hub", "tether-agent", "tetherctl"} {
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
