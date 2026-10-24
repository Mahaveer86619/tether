package agent

import "github.com/Mahaveer86619/tether/server/internal/indexer"

const defaultTetherignore = indexer.DefaultTetherignore

type ignoreRules = indexer.IgnoreRules

func parseIgnore(text string) ignoreRules {
	return indexer.ParseIgnore(text)
}

func isEnvFile(name string) bool {
	return indexer.IsEnvFile(name)
}
