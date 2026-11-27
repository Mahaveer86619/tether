package hub

import (
	"embed"
	"fmt"
	"sort"
	"strings"
)

// The guide is what a session reads to learn how Tether works: its parts, where
// it keeps data, what is built and which tools it has. It is embedded so the
// hub always serves the text that matches its own version.
//
//go:embed guide/*.md
var guideFS embed.FS

func guideTopics() []string {
	entries, _ := guideFS.ReadDir("guide")
	var out []string
	for _, e := range entries {
		out = append(out, strings.TrimSuffix(e.Name(), ".md"))
	}
	sort.Strings(out)
	return out
}

func (h *Hub) mcpGuide(caller identity, args map[string]any) (string, error) {
	topic := strings.ToLower(strings.TrimSpace(str(args, "topic")))
	if topic == "" {
		topic = "overview"
	}
	b, err := guideFS.ReadFile("guide/" + topic + ".md")
	if err != nil {
		return "", fmt.Errorf("no guide topic %q; the topics are %s", topic, strings.Join(guideTopics(), ", "))
	}
	return string(b), nil
}

// guidePrompt points a session at the guide.
const guidePrompt = "\n\nTether's own guide: the tether tool tether_guide explains how Tether works (topics overview, data, features, tools). " +
	"Read it before you analyse Tether's saved data or change how Tether works; most of what it keeps is in protobuf blobs."
