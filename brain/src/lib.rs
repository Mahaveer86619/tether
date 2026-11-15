//! Tether's second brain: memories, notes and references that sessions can
//! recall, kept in one SQLite file and ranked by keywords and likeness.

pub mod embed;
pub mod markdown;
pub mod mcp;
pub mod store;

pub use store::{now_ms, Brain, Context, Error, Hit, Link, Memory, NewMemory, Query, Result, Scope};
