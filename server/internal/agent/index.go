package agent

import (
	"github.com/Mahaveer86619/tether/server/internal/indexer"
)

// Index tracks the sessions Claude Code has written under ~/.claude/projects.
type Index = indexer.Index

// NewIndex creates a new index scanning the given projects directory.
func NewIndex(dir string) *Index {
	return indexer.New(dir)
}

func firstNonEmpty(ss ...string) string {
	for _, s := range ss {
		if s != "" {
			return s
		}
	}
	return ""
}
