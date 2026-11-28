package main

type welcomeState struct {
	Sessions    []sessionState `json:"sessions"`
	Chats       []chatState    `json:"chats"`
	TokenStatus tokenStatus    `json:"tokenStatus"`
}

type sessionState struct {
	ID         string `json:"id"`
	Node       string `json:"node"`
	Title      string `json:"title"`
	State      string `json:"state"`
	Profile    string `json:"profile"`
	Model      string `json:"model"`
	ParentTask string `json:"parentTask"`
}

type chatState struct {
	ID            string     `json:"id"`
	Title         string     `json:"title"`
	ActiveSession string     `json:"activeSession"`
	Sessions      []chatLink `json:"sessions"`
}

type chatLink struct {
	Session string `json:"session"`
	Role    string `json:"role"`
}

type tokenStatus struct {
	LastDecision string           `json:"lastDecision"`
	LastReason   string           `json:"lastReason"`
	Providers    []providerBudget `json:"providers"`
}

type providerBudget struct {
	Provider        string `json:"provider"`
	Model           string `json:"model"`
	Rank            int32  `json:"rank"`
	Enabled         bool   `json:"enabled"`
	QuotaState      string `json:"quotaState"`
	RemainingTokens int64  `json:"remainingTokens"`
}

func (w welcomeState) sessionIDsFor(chatID string) []string {
	for _, c := range w.Chats {
		if c.ID != chatID {
			continue
		}
		ids := make([]string, 0, len(c.Sessions)+1)
		if c.ActiveSession != "" {
			ids = append(ids, c.ActiveSession)
		}
		for _, l := range c.Sessions {
			if l.Session != "" && !contains(ids, l.Session) {
				ids = append(ids, l.Session)
			}
		}
		return ids
	}
	return nil
}

func (t tokenStatus) quotaSummary() string {
	var exhausted []string
	var remaining int64
	for _, p := range t.Providers {
		if !p.Enabled {
			continue
		}
		remaining += p.RemainingTokens
		if p.QuotaState == "exhausted" || p.QuotaState == "unavailable" {
			name := p.Provider
			if p.Model != "" {
				name += "/" + p.Model
			}
			exhausted = append(exhausted, name)
		}
	}
	summary := "remaining " + formatTokens(remaining)
	if len(exhausted) > 0 {
		summary += "; down " + exhausted[0]
		if len(exhausted) > 1 {
			summary += " +" + itoa(int64(len(exhausted)-1))
		}
	}
	return clip(summary, 80)
}

func contains(list []string, want string) bool {
	for _, s := range list {
		if s == want {
			return true
		}
	}
	return false
}

func formatTokens(n int64) string {
	if n >= 1_000_000 {
		return itoa(n/1_000_000) + "M"
	}
	if n >= 1_000 {
		return itoa(n/1_000) + "k"
	}
	return itoa(n)
}
