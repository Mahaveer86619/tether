# Local AI on the GPU device: OCR, embeddings, compression

Status: plan. Written after reading the READMEs of the two projects below (not their code, and nothing was installed or run). It sets what to use from each and how the GPU desktop fits.

## What was looked at

| Project | What it is | Licence | Fit |
|---|---|---|---|
| **Headroom** (`headroomlabs-ai/headroom`) | Compresses what an agent reads (tool output, logs, JSON, code, RAG chunks, history) before it reaches the model; a Python library, a local proxy, an MCP server and `headroom wrap claude`. Reports 21 to 57% fewer input tokens on four agent scenarios and 90%+ on repeated JSON or log lines, little on prose; originals kept locally and retrievable (CCR); compression runs on the machine | Apache 2.0, active (pushed this week) | **Good fit** for Tether's cost problem. Piloted, not adopted blindly |
| **Mirage** (`UMass-Embodied-AGI/Mirage`) | A CVPR 2026 research model: Qwen2.5-VL-7B trained to interleave *latent visual tokens* with text for multimodal reasoning (spatial planning tasks); training and test code, small sample data | No licence file found | **Not a component.** It is a training recipe for one model and one task family, not an OCR or retrieval tool. Worth reading for ideas; not integrated |

## Why Headroom matters here

The analysis of this hub's data (see [prompt-desk.md](prompt-desk.md#what-the-data-says)) found 98% of input-side tokens are cache reads over contexts of hundreds of millions of tokens, and a 5-hour limit that long sessions hit. Headroom targets exactly the part Tether can shrink: tool results and logs a session re-reads.

**Ways it could plug in, smallest first:**

1. **Per-device wrapping.** The agent starts `claude` through a Headroom proxy (`headroom wrap claude`, or the proxy plus `ANTHROPIC_BASE_URL`). A per-device setting, off by default, with a health check and a clean unwrap. The sessions are unchanged; the prompt gets smaller.
2. **The hub's own MCP output.** `read_session`, `read_artifact` and `list_sessions` return long text to a lead. Compress those results with the library, with retrieval of the original on request.
3. **Its ideas, in Tether's own parts.** `headroom learn` (mining failed sessions into rules) is what Insights and Rules do; cross-agent memory is what the second brain does. Take the *method* (what to mine, how to write the correction) rather than a second system.

**Risks to check before turning it on:**

- **Credentials pass through the proxy.** With a subscription login, the proxy sits in the path of the account's requests. It runs locally and the README says nothing leaves the machine, but this must be confirmed in its code before any real account goes through it.
- **Caching.** Rewriting the prompt can break the provider's prefix cache, which is where 98% of the cheap tokens come from. Its CacheAligner is meant to avoid that; the pilot measures it.
- **Another runtime** (Python 3.13, `uv`) on every device that uses it.
- **Quality.** Compressed tool output must not hide the line that mattered. The pilot compares answers, not only tokens.

**Pilot.** Wrap one device's sessions for a week, run the same kinds of tasks on an unwrapped device, and compare with the usage tracking in [token-pool.md](token-pool.md#1-tracking): tokens and percent of window per task, cache-hit share, failures and retries. Adopt only if the saving is real and answers did not get worse.

## The GPU device: OCR and local retrieval

The desktop with a GTX 1080 Ti (11 GB, Pascal) and the mini PC are on one tailnet. The second brain ([second-brain-rust.md](second-brain-rust.md)) runs on the mini PC with a light local embedder; the GPU box can do better for the heavy parts and stays optional.

**A small inference service on the GPU device**, started as a Tether *job* ([shared-workspace.md](shared-workspace.md#jobs)) so it can be paused when the owner uses the machine: an HTTP service on the tailnet only, with two endpoints.

| Endpoint | Does | Candidates |
|---|---|---|
| `/ocr` | Text and layout from an image or a PDF page | PaddleOCR, docTR, or Tesseract as the plain fallback |
| `/embed` | Embeddings for text chunks | a small multilingual embedding model (bge or e5 class) |

**How the hub uses it.**

- **OCR on attachments and screenshots.** When an image or a scanned PDF is attached to a chat or saved as an artifact, the hub asks `/ocr` and stores the text beside it, so it can be searched and so a session can read it as text. Without the service it is skipped; nothing breaks.
- **Local retrieval.** The brain sends chunks (notes, chat history, codebase docs, OCR text) to `/embed` and keeps the vectors in its own SQLite file on the mini PC; `recall` and a new *search my history* use them. If the GPU box is off, the brain falls back to its current light embedder, and vectors from the two are never mixed (the store records which embedder made each).
- **Nothing leaves the tailnet**: the service listens on the tailnet address, takes a hub token, and holds no data of its own.

**Limits to know about the card.** A 1080 Ti has 11 GB of memory, no bf16 and no flash-attention, and recent framework builds are dropping support for Pascal-class cards, so the service uses ONNX Runtime or a pinned older framework build; this must be verified on the machine first. An 11 GB card can run OCR models and small embedding models comfortably, and a 7B vision-language model only quantised. Mirage's 7B model is not trainable on it.

## Build order

1. **Headroom pilot** on one device, behind a per-device setting; the measurement above.
2. **The GPU service as a job**: `/embed` first (it helps recall most), then `/ocr`; capability reported by the device (see jobs), found by the hub by name.
3. **Brain embedder switch**: a pluggable embedder with a record of which made each vector; re-embed in the background when the service is up.
4. **OCR on attachments** and a *search my history* box in the app.
5. **Headroom on the hub's MCP output** if the pilot paid off.

## Tests

- **Embedder**: vectors from two embedders are never compared; switching embedders re-embeds without losing notes; with the service down, recall still answers.
- **OCR**: a sample image with known text returns it; a service failure leaves the attachment untouched.
- **Service**: refuses a request without the token; a paused job answers nothing and resumes cleanly.
- **Compression** (if adopted): a log with one fatal line keeps the line; originals are retrievable; the cache-hit share does not drop in the pilot.

## Decisions

- Whether Headroom should be piloted on a device now, and which one.
- Which OCR engine to start with (PaddleOCR for accuracy, Tesseract for no GPU dependency).
- Whether the embedding model may be downloaded from a public model hub on the GPU box.
