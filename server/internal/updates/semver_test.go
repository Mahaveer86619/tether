package updates

import "testing"

func TestAtLeast(t *testing.T) {
	cases := []struct {
		a, b string
		want bool
	}{
		{"0.17.0", "0.17.0", true},
		{"0.17.1", "0.17.0", true},
		{"0.17.0", "0.17.1", false},
		{"1.0.0", "0.99.99", true},
		{"v1.2.3", "1.2.3", true},
		{"0.16.5", "0.17.0", false},
	}
	for _, c := range cases {
		if got := AtLeast(c.a, c.b); got != c.want {
			t.Errorf("AtLeast(%q, %q) = %v, want %v", c.a, c.b, got, c.want)
		}
	}
}
