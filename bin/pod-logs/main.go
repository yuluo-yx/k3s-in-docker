package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	kubeconfig := flag.String("kubeconfig", defaultKubeconfig(), "path to kubeconfig file")
	namespace := flag.String("namespace", "default", "kubernetes namespace")
	podName := flag.String("pod", "", "pod name (omit to auto-select the first running pod)")
	container := flag.String("container", "", "container name (omit for pod with single container)")
	follow := flag.Bool("follow", false, "follow the log stream (like tail -f)")
	tailLines := flag.Int64("tail", 100, "number of recent lines to display (0 for all)")
	previous := flag.Bool("previous", false, "show previous terminated container logs")
	flag.Parse()

	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error building kubeconfig: %v\n", err)
		os.Exit(1)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error building clientset: %v\n", err)
		os.Exit(1)
	}

	ns := *namespace
	targetPod := *podName

	if targetPod == "" {
		pods, err := clientset.CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{})
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error listing pods: %v\n", err)
			os.Exit(1)
		}

		var runningPods []corev1.Pod
		for _, p := range pods.Items {
			if p.Status.Phase == "Running" {
				runningPods = append(runningPods, p)
			}
		}

		if len(runningPods) == 0 {
			fmt.Fprintf(os.Stderr, "No running pods found in namespace %q\n", ns)
			os.Exit(1)
		}

		if len(runningPods) == 1 {
			targetPod = runningPods[0].Name
			ns = runningPods[0].Namespace
		} else {
			fmt.Println("Running pods:")
			for i, p := range runningPods {
				fmt.Printf("  [%d] %s/%s\n", i+1, p.Namespace, p.Name)
			}
			fmt.Printf("\nMultiple pods found. Please specify --pod <name>\n")
			os.Exit(1)
		}
	}

	opts := &corev1.PodLogOptions{
		Follow:     *follow,
		Previous:   *previous,
		Timestamps: true,
	}
	if *tailLines > 0 {
		opts.TailLines = tailLines
	}
	if *container != "" {
		opts.Container = *container
	}

	fmt.Printf("📋 Logs for pod %q in namespace %q:\n", targetPod, ns)
	fmt.Println(strings.Repeat("-", 60))

	req := clientset.CoreV1().Pods(ns).GetLogs(targetPod, opts)
	stream, err := req.Stream(context.Background())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error streaming logs: %v\n", err)
		os.Exit(1)
	}
	defer stream.Close()

	buf := make([]byte, 4096)
	for {
		n, err := stream.Read(buf)
		if n > 0 {
			os.Stdout.Write(buf[:n])
		}
		if err != nil {
			break
		}
	}
}

func defaultKubeconfig() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".kube", "k3s", "kubeconfig")
}
