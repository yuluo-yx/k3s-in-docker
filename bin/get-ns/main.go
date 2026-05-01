package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"text/tabwriter"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	kubeconfig := flag.String("kubeconfig", defaultKubeconfig(), "path to kubeconfig file")
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

	namespaces, err := clientset.CoreV1().Namespaces().List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error listing namespaces: %v\n", err)
		os.Exit(1)
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "NAME\tSTATUS\tAGE")
	for _, ns := range namespaces.Items {
		age := formatAge(ns.CreationTimestamp)
		fmt.Fprintf(w, "%s\t%s\t%s\n", ns.Name, ns.Status.Phase, age)
	}
	w.Flush()
}

func defaultKubeconfig() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".kube", "k3s", "kubeconfig")
}

func formatAge(t metav1.Time) string {
	diff := metav1.Now().Unix() - t.Unix()
	switch {
	case diff < 60:
		return fmt.Sprintf("%ds", diff)
	case diff < 3600:
		return fmt.Sprintf("%dm", diff/60)
	case diff < 86400:
		return fmt.Sprintf("%dh", diff/3600)
	default:
		return fmt.Sprintf("%dd", diff/86400)
	}
}
