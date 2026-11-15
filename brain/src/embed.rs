//! A small embedder that needs no model: words and their pieces are hashed into
//! a fixed-size vector (feature hashing), weighted sub-linearly, and
//! normalised. Two texts that share words or word pieces get vectors that
//! point the same way, which is all recall needs next to keyword ranking.
//! Everything is deterministic, so vectors stored today still compare with
//! vectors made next year.

pub const DIMS: usize = 256;

const STOP: &[&str] = &[
    "a", "an", "and", "are", "as", "at", "be", "but", "by", "for", "from", "has", "have", "if", "in", "is", "it", "its", "of", "on", "or", "that", "the",
    "this", "to", "was", "we", "were", "will", "with",
];

fn fnv1a(bytes: &[u8], seed: u64) -> u64 {
    let mut h = 0xcbf29ce484222325u64 ^ seed.wrapping_mul(0x9e3779b97f4a7c15);
    for b in bytes {
        h ^= *b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

/// Splits text into lowercase words, and identifiers into their parts:
/// `fetchUserName` gives `fetch`, `user`, `name` as well as the whole.
pub fn tokens(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    for raw in text.split(|c: char| !(c.is_alphanumeric() || c == '_')) {
        if raw.is_empty() {
            continue;
        }
        let whole = raw.to_lowercase();
        let parts = split_identifier(raw);
        if parts.len() > 1 {
            for p in parts {
                push_token(&mut out, p);
            }
        }
        push_token(&mut out, whole);
    }
    out
}

fn push_token(out: &mut Vec<String>, t: String) {
    let t = t.trim_matches('_').to_string();
    if t.chars().count() < 2 || STOP.contains(&t.as_str()) {
        return;
    }
    out.push(t);
}

fn split_identifier(s: &str) -> Vec<String> {
    let mut parts = Vec::new();
    let mut cur = String::new();
    let chars: Vec<char> = s.chars().collect();
    for (i, &c) in chars.iter().enumerate() {
        if c == '_' {
            if !cur.is_empty() {
                parts.push(std::mem::take(&mut cur));
            }
            continue;
        }
        let boundary = i > 0
            && c.is_uppercase()
            && (chars[i - 1].is_lowercase() || chars[i - 1].is_numeric() || (i + 1 < chars.len() && chars[i + 1].is_lowercase() && chars[i - 1].is_uppercase()));
        if boundary && !cur.is_empty() {
            parts.push(std::mem::take(&mut cur));
        }
        cur.extend(c.to_lowercase());
    }
    if !cur.is_empty() {
        parts.push(cur);
    }
    parts
}

fn add(v: &mut [f32; DIMS], feature: &[u8], seed: u64, weight: f32) {
    let h = fnv1a(feature, seed);
    let slot = (h % DIMS as u64) as usize;
    let sign = if (h >> 40) & 1 == 0 { 1.0 } else { -1.0 };
    v[slot] += sign * weight;
}

/// The vector for a text: unit length, or all zeros for a text with nothing in it.
pub fn embed(text: &str) -> [f32; DIMS] {
    let toks = tokens(text);
    let mut v = [0f32; DIMS];
    for t in &toks {
        add(&mut v, t.as_bytes(), 1, 1.0);
        // Pieces of the word, so "indexing" and "indexed" meet.
        let padded: Vec<char> = format!("^{t}$").chars().collect();
        if padded.len() >= 4 {
            for w in padded.windows(3) {
                let g: String = w.iter().collect();
                add(&mut v, g.as_bytes(), 2, 0.35);
            }
        }
    }
    for pair in toks.windows(2) {
        add(&mut v, format!("{} {}", pair[0], pair[1]).as_bytes(), 3, 0.6);
    }
    for x in v.iter_mut() {
        *x = x.signum() * (1.0 + x.abs()).ln();
    }
    let norm = v.iter().map(|x| x * x).sum::<f32>().sqrt();
    if norm > 0.0 {
        for x in v.iter_mut() {
            *x /= norm;
        }
    }
    v
}

/// A vector as bytes, one signed byte per dimension: a quarter of the size, and
/// the cosine is still good to about two decimals.
pub fn quantize(v: &[f32; DIMS]) -> Vec<u8> {
    v.iter().map(|x| (x * 127.0).round().clamp(-127.0, 127.0) as i8 as u8).collect()
}

/// The cosine of two quantised unit vectors.
pub fn cosine(a: &[u8], b: &[u8]) -> f32 {
    if a.len() != DIMS || b.len() != DIMS {
        return 0.0;
    }
    let mut dot = 0i32;
    for i in 0..DIMS {
        dot += (a[i] as i8 as i32) * (b[i] as i8 as i32);
    }
    dot as f32 / (127.0 * 127.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sim(a: &str, b: &str) -> f32 {
        cosine(&quantize(&embed(a)), &quantize(&embed(b)))
    }

    #[test]
    fn identifiers_split_into_their_words() {
        assert_eq!(tokens("fetchUserName"), vec!["fetch", "user", "name", "fetchusername"]);
        assert_eq!(tokens("snake_case_name"), vec!["snake", "case", "name", "snake_case_name"]);
        assert_eq!(tokens("HTTPServer"), vec!["http", "server", "httpserver"]);
    }

    #[test]
    fn stop_words_and_single_letters_are_dropped() {
        assert_eq!(tokens("a to the of x"), Vec::<String>::new());
    }

    #[test]
    fn vectors_are_unit_length_and_repeatable() {
        let v = embed("the hub keeps every session's history");
        let n: f32 = v.iter().map(|x| x * x).sum::<f32>().sqrt();
        assert!((n - 1.0).abs() < 1e-4);
        assert_eq!(embed("same text"), embed("same text"));
        assert!(embed("").iter().all(|x| *x == 0.0));
    }

    #[test]
    fn related_texts_are_closer_than_unrelated_ones() {
        let near = sim("restart the tunnel when cloudflared exits", "cloudflared tunnel restarts after it exits");
        let far = sim("restart the tunnel when cloudflared exits", "the colour of the settings screen chips");
        assert!(near > far + 0.2, "near {near} far {far}");
    }

    #[test]
    fn word_pieces_let_inflections_meet() {
        assert!(sim("indexing", "indexed") > sim("indexing", "colour"));
    }

    #[test]
    fn quantising_keeps_the_cosine() {
        let a = embed("sqlite full text search ranking");
        let b = embed("ranking results with sqlite fts");
        let exact: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
        let approx = cosine(&quantize(&a), &quantize(&b));
        assert!((exact - approx).abs() < 0.03, "exact {exact} approx {approx}");
    }
}
