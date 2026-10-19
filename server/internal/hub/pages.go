package hub

import (
	"fmt"
	"net/http"
	"os"
	"path"
	"strconv"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Pages are small sites a session writes under .tether/pages/<name>/; see
// docs/plan.md#generated-pages. They're served at
// /p/<session>/<name>/<exp>/<sig>/<file>, so relative links between their
// files resolve, and sandboxed so a page can't act as the hub's origin.

const pageLinkTTL = 7 * 24 * time.Hour

// pages lists the pages of a session, or of all sessions, newest first.
// Caller holds h.mu.
func (h *Hub) pages(session string) (*v1.PageList, *opError) {
	files, err := h.store.PageFiles(session)
	if err != nil {
		return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
	}
	byKey := map[string]*v1.Page{}
	out := &v1.PageList{}
	for _, f := range files {
		name, _, ok := strings.Cut(f.Path, "/")
		if !ok {
			continue
		}
		key := f.Session + "/" + name
		p := byKey[key]
		if p == nil {
			p = &v1.Page{Session: f.Session, Name: name}
			byKey[key] = p
			out.Pages = append(out.Pages, p)
		}
		p.Files++
		p.Size += f.Size
		p.UpdatedMs = max(p.UpdatedMs, f.CreatedMs)
	}
	exp := time.Now().Add(pageLinkTTL).UnixMilli()
	for _, p := range out.Pages {
		p.Url, p.ExpiresMs = h.pageURL(p.Session, p.Name, exp), exp
	}
	return out, nil
}

func (h *Hub) pageURL(session, name string, exp int64) string {
	return fmt.Sprintf("/p/%s/%s/%d/%s/index.html", session, name, exp, h.sign(pageKey(session, name), exp))
}

func pageKey(session, name string) string { return "page:" + session + "/" + name }

// servePage answers /p/{session}/{name}/{exp}/{sig}/{file...} for anyone
// holding a valid link.
func (h *Hub) servePage(w http.ResponseWriter, r *http.Request) {
	session, name := r.PathValue("session"), r.PathValue("name")
	exp, err := strconv.ParseInt(r.PathValue("exp"), 10, 64)
	if err != nil || time.Now().UnixMilli() > exp || r.PathValue("sig") != h.sign(pageKey(session, name), exp) {
		http.Error(w, "this link has expired; open the page again from Tether", http.StatusForbidden)
		return
	}
	file := path.Clean("/" + r.PathValue("file"))[1:]
	if file == "" || strings.HasSuffix(r.URL.Path, "/") {
		file = path.Join(file, "index.html")
	}
	h.mu.Lock()
	a, err := h.store.PageFile(session, name+"/"+file)
	h.mu.Unlock()
	if err != nil || a == nil {
		http.NotFound(w, r)
		return
	}
	f, err := os.Open(h.blobPath(a.Sha256))
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer f.Close()
	// An opaque origin: scripts run, but can't read the hub's storage or call its API as the page.
	w.Header().Set("Content-Security-Policy", "sandbox allow-scripts allow-forms allow-popups allow-modals allow-downloads")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Content-Type", mimeOf("", a.Name))
	w.Header().Set("Cache-Control", "no-cache")
	http.ServeContent(w, r, "", time.UnixMilli(a.CreatedMs), f)
}
