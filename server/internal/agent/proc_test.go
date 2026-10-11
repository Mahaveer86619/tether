package agent

import (
	"os"
	"os/exec"
	"testing"
)

func TestProcessAlive(t *testing.T) {
	if !processAlive(uint32(os.Getpid())) {
		t.Fatal("own process reported dead")
	}
	cmd := exec.Command(os.Args[0], "-test.run=^$")
	if err := cmd.Run(); err != nil {
		t.Fatal(err)
	}
	if processAlive(uint32(cmd.Process.Pid)) {
		t.Fatal("exited process reported alive")
	}
}
