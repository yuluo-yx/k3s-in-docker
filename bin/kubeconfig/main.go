package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	container := flag.String("container", "nginx-k3s-server", "k3s container name")
	output := flag.String("output", "", "output path for kubeconfig (default: ~/.kube/k3s/kubeconfig)")
	overwrite := flag.Bool("overwrite", false, "overwrite existing kubeconfig if it exists")
	flag.Parse()

	outputPath := *output
	if outputPath == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error getting home directory: %v\n", err)
			os.Exit(1)
		}
		outputPath = filepath.Join(home, ".kube", "k3s", "kubeconfig")
	}

	if !isContainerRunning(*container) {
		fmt.Fprintf(os.Stderr, "Error: container %q is not running\n", *container)
		os.Exit(1)
	}

	if _, err := os.Stat(outputPath); err == nil && !*overwrite {
		fmt.Fprintf(os.Stderr, "Error: kubeconfig already exists at %q (use --overwrite to replace)\n", outputPath)
		os.Exit(1)
	}

	fmt.Printf("📦 Extracting kubeconfig from container %q ...\n", *container)
	kubeconfig, err := extractKubeconfig(*container)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error extracting kubeconfig: %v\n", err)
		os.Exit(1)
	}

	dir := filepath.Dir(outputPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating directory %q: %v\n", dir, err)
		os.Exit(1)
	}

	if err := os.WriteFile(outputPath, []byte(kubeconfig), 0600); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing kubeconfig: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("✅ Kubeconfig saved to %q\n", outputPath)
	fmt.Printf("   Use it with: export KUBECONFIG=%s\n", outputPath)
	fmt.Printf("   Or: kubectl --kubeconfig=%s get nodes\n", outputPath)
}

func isContainerRunning(name string) bool {
	cmd := exec.Command("docker", "inspect", "-f", "{{.State.Running}}", name)
	out, err := cmd.Output()
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(out)) == "true"
}

func extractKubeconfig(container string) (string, error) {
	cmd := exec.Command("docker", "exec", container, "cat", "/etc/rancher/k3s/k3s.yaml")
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to read kubeconfig from container: %w", err)
	}
	return string(out), nil
}
