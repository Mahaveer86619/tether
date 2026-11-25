package agent

import (
	"context"
	"errors"
	"testing"
)

func TestNvidiaSmiGPUsAreReadWithTheirMemory(t *testing.T) {
	run := func(_ context.Context, name string, _ ...string) ([]byte, error) {
		if name == "nvidia-smi" {
			return []byte("NVIDIA GeForce RTX 4090, 24564\nNVIDIA GeForce RTX 3060, 12288\n"), nil
		}
		return nil, errors.New("not found")
	}
	gpus := findGPUs(context.Background(), run)
	if len(gpus) != 2 || gpus[0].Name != "NVIDIA GeForce RTX 4090" || gpus[0].MemoryBytes != 24564<<20 {
		t.Fatalf("got %v", gpus)
	}
	if !hasGPU(gpus) {
		t.Fatal("an RTX card is a GPU")
	}
}

func TestWindowsVideoControllersSkipBasicAdaptersAndCappedMemory(t *testing.T) {
	gpus := parseVideoControllers([]byte(`[{"Name":"NVIDIA GeForce RTX 4070","AdapterRAM":4293918720},{"Name":"Intel(R) UHD Graphics","AdapterRAM":1073741824},{"Name":"Microsoft Basic Display Adapter","AdapterRAM":0}]`))
	if len(gpus) != 2 {
		t.Fatalf("got %v", gpus)
	}
	if gpus[0].MemoryBytes != 0 {
		t.Fatalf("a 4 GB reading is the field's cap, not the card's memory: %d", gpus[0].MemoryBytes)
	}
	if gpus[1].MemoryBytes != 1<<30 {
		t.Fatalf("integrated memory: %d", gpus[1].MemoryBytes)
	}
	if hasGPU(gpus[1:]) {
		t.Fatal("integrated graphics is not a compute GPU")
	}
	if one := parseVideoControllers([]byte(`{"Name":"AMD Radeon RX 7900 XTX","AdapterRAM":2147483648}`)); len(one) != 1 || !hasGPU(one) {
		t.Fatalf("a single controller: %v", one)
	}
}

func TestMeminfoTotal(t *testing.T) {
	if got := parseMeminfo("MemFree: 5 kB\nMemTotal:       16303488 kB\n"); got != 16303488<<10 {
		t.Fatalf("got %d", got)
	}
}
