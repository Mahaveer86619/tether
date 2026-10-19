package hub

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Resumable uploads, for files too big to send in one go over a phone's
// connection. See docs/plan.md#large-files.

const staleUpload = 24 * time.Hour

func (h *Hub) uploadDir() string { return filepath.Join(h.cfg.DataDir, "uploads") }

// pendingUpload is what POST /api/v1/uploads was told, kept next to the
// partial file so an upload survives a hub restart.
type pendingUpload struct {
	Artifact []byte `json:"artifact"`
	Size     int64  `json:"size"`
	Deliver  bool   `json:"deliver"`
	// Set once stored, so a client that lost the last answer can ask again.
	Done bool `json:"done,omitempty"`
}

func (h *Hub) uploadRoutes(mux *http.ServeMux) {
	authed := func(fn func(http.ResponseWriter, *http.Request, identity)) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			id, err := h.auth(r, true)
			if err != nil {
				writeError(w, err)
				return
			}
			fn(w, r, id)
		}
	}
	mux.HandleFunc("POST /api/v1/uploads", authed(h.startUpload))
	mux.HandleFunc("GET /api/v1/uploads/{id}", authed(func(w http.ResponseWriter, r *http.Request, _ identity) {
		u, _, err := h.loadUpload(r.PathValue("id"))
		if err != nil {
			writeError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, u)
	}))
	mux.HandleFunc("PATCH /api/v1/uploads/{id}", authed(func(w http.ResponseWriter, r *http.Request, _ identity) {
		h.appendUpload(w, r)
	}))
	mux.HandleFunc("DELETE /api/v1/uploads/{id}", authed(func(w http.ResponseWriter, r *http.Request, _ identity) {
		id := r.PathValue("id")
		if _, _, err := h.loadUpload(id); err != nil {
			writeError(w, err)
			return
		}
		h.dropUpload(id)
		writeJSON(w, http.StatusOK, &v1.Ack{})
	}))
}

// startUpload takes the same headers as POST /api/v1/artifacts, plus X-Size.
func (h *Hub) startUpload(w http.ResponseWriter, r *http.Request, id identity) {
	a, oerr := artifactFromHeaders(r, id)
	if oerr != nil {
		writeError(w, oerr)
		return
	}
	size, err := strconv.ParseInt(r.Header.Get("X-Size"), 10, 64)
	if err != nil || size < 0 {
		writeError(w, invalid("X-Size is required"))
		return
	}
	if err := os.MkdirAll(h.uploadDir(), 0o755); err != nil {
		writeError(w, internalError(err))
		return
	}
	b, err := proto.Marshal(a)
	if err != nil {
		writeError(w, internalError(err))
		return
	}
	u := &v1.Upload{Id: uuid.NewString(), Size: size}
	meta, _ := json.Marshal(pendingUpload{Artifact: b, Size: size, Deliver: wantsDelivery(r)})
	if err := os.WriteFile(h.uploadPath(u.Id)+".json", meta, 0o600); err != nil {
		writeError(w, internalError(err))
		return
	}
	if err := os.WriteFile(h.uploadPath(u.Id), nil, 0o600); err != nil {
		writeError(w, internalError(err))
		return
	}
	if size == 0 {
		h.finishUpload(w, u.Id)
		return
	}
	writeJSON(w, http.StatusOK, u)
}

func (h *Hub) uploadPath(id string) string { return filepath.Join(h.uploadDir(), id) }

func (h *Hub) loadUpload(id string) (*v1.Upload, *pendingUpload, *opError) {
	if uuid.Validate(id) != nil {
		return nil, nil, &opError{"not_found", "unknown upload", http.StatusNotFound}
	}
	b, err := os.ReadFile(h.uploadPath(id) + ".json")
	if err != nil {
		return nil, nil, &opError{"not_found", "unknown upload; start it again", http.StatusNotFound}
	}
	p := &pendingUpload{}
	if err := json.Unmarshal(b, p); err != nil {
		return nil, nil, internalError(err)
	}
	if p.Done {
		a := &v1.Artifact{}
		if err := proto.Unmarshal(p.Artifact, a); err != nil {
			return nil, nil, internalError(err)
		}
		return &v1.Upload{Id: id, Offset: p.Size, Size: p.Size, Artifact: a}, p, nil
	}
	st, err := os.Stat(h.uploadPath(id))
	if err != nil {
		// Between moving the file into the store and recording that it's done.
		return nil, nil, &opError{"busy", "the upload is being stored; ask again", http.StatusConflict}
	}
	return &v1.Upload{Id: id, Offset: st.Size(), Size: p.Size}, p, nil
}

// appendUpload writes the body at Upload-Offset, which must be where the
// file ends now. The chunk that completes it stores the artifact.
func (h *Hub) appendUpload(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !h.claimUpload(id) {
		writeError(w, &opError{"busy", "another request is writing this upload", http.StatusConflict})
		return
	}
	defer h.releaseUpload(id)
	u, _, oerr := h.loadUpload(id)
	if oerr != nil {
		writeError(w, oerr)
		return
	}
	if u.Artifact != nil {
		writeJSON(w, http.StatusOK, u)
		return
	}
	off, err := strconv.ParseInt(r.Header.Get("Upload-Offset"), 10, 64)
	if err != nil {
		writeError(w, invalid("Upload-Offset is required"))
		return
	}
	if off != u.Offset {
		w.Header().Set("Upload-Offset", strconv.FormatInt(u.Offset, 10))
		writeError(w, &opError{"offset", fmt.Sprintf("the upload is at %d, not %d", u.Offset, off), http.StatusConflict})
		return
	}
	f, err := os.OpenFile(h.uploadPath(id), os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		writeError(w, internalError(err))
		return
	}
	// A cut-off chunk keeps what arrived; the client asks where to go on.
	_, err = io.Copy(f, io.LimitReader(r.Body, u.Size-u.Offset))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		writeError(w, writeFailure(err))
		return
	}
	if u, _, oerr = h.loadUpload(id); oerr != nil {
		writeError(w, oerr)
		return
	}
	if u.Offset < u.Size {
		writeJSON(w, http.StatusOK, u)
		return
	}
	h.finishUpload(w, id)
}

// finishUpload hashes the whole file (a hash can't be carried across
// requests and restarts), checks it, and files it in the store.
func (h *Hub) finishUpload(w http.ResponseWriter, id string) {
	u, p, oerr := h.loadUpload(id)
	if oerr != nil {
		writeError(w, oerr)
		return
	}
	a := &v1.Artifact{}
	if err := proto.Unmarshal(p.Artifact, a); err != nil {
		writeError(w, internalError(err))
		return
	}
	f, err := os.Open(h.uploadPath(id))
	if err != nil {
		writeError(w, internalError(err))
		return
	}
	sum := sha256.New()
	_, err = io.Copy(sum, f)
	f.Close()
	if err != nil {
		writeError(w, internalError(err))
		return
	}
	sha := hex.EncodeToString(sum.Sum(nil))
	if a.Sha256 != "" && sha != a.Sha256 {
		h.dropUpload(id)
		writeError(w, &opError{"checksum", "the file doesn't match its sha256; upload it again", http.StatusUnprocessableEntity})
		return
	}
	if err := h.keepBlob(h.uploadPath(id), sha); err != nil {
		writeError(w, internalError(err))
		return
	}
	a.Sha256, a.Size = sha, u.Size
	h.mu.Lock()
	oerr = h.addArtifact(a)
	if oerr == nil && p.Deliver {
		h.deliverAttachment(a)
	}
	h.mu.Unlock()
	if oerr != nil {
		h.dropUpload(id)
		writeError(w, oerr)
		return
	}
	if b, err := proto.Marshal(a); err == nil {
		p.Artifact, p.Done = b, true
		meta, _ := json.Marshal(p)
		_ = os.WriteFile(h.uploadPath(id)+".json", meta, 0o600)
	}
	u.Offset, u.Artifact = u.Size, a
	writeJSON(w, http.StatusOK, u)
}

func (h *Hub) dropUpload(id string) {
	_ = os.Remove(h.uploadPath(id))
	_ = os.Remove(h.uploadPath(id) + ".json")
}

func (h *Hub) claimUpload(id string) bool {
	h.uploadMu.Lock()
	defer h.uploadMu.Unlock()
	if h.uploading == nil {
		h.uploading = map[string]bool{}
	}
	if h.uploading[id] {
		return false
	}
	h.uploading[id] = true
	return true
}

func (h *Hub) releaseUpload(id string) {
	h.uploadMu.Lock()
	delete(h.uploading, id)
	h.uploadMu.Unlock()
}

// dropStaleUploads removes uploads nobody has added to for a day.
func (h *Hub) dropStaleUploads(now time.Time) {
	entries, err := os.ReadDir(h.uploadDir())
	if err != nil {
		return
	}
	for _, e := range entries {
		id, ok := strings.CutSuffix(e.Name(), ".json")
		if !ok || uuid.Validate(id) != nil {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		last := info.ModTime()
		// Chunks change the partial file, not its details.
		if part, err := os.Stat(h.uploadPath(id)); err == nil && part.ModTime().After(last) {
			last = part.ModTime()
		}
		if now.Sub(last) > staleUpload && h.claimUpload(id) {
			h.dropUpload(id)
			h.releaseUpload(id)
		}
	}
}
