package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"text/tabwriter"
	"time"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	kubeconfig := flag.String("kubeconfig", defaultKubeconfig(), "path to kubeconfig file")
	namespace := flag.String("namespace", "", "namespace to check (empty = all namespaces)")
	watch := flag.Bool("watch", false, "continuously watch health status")
	interval := flag.Int("interval", 5, "watch interval in seconds")
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

	if *watch {
		for {
			printHealth(clientset, *namespace)
			fmt.Printf("\n--- refreshing in %ds (Ctrl+C to stop) ---\n\n", *interval)
			time.Sleep(time.Duration(*interval) * time.Second)
		}
	}

	printHealth(clientset, *namespace)
}

func printHealth(clientset *kubernetes.Clientset, ns string) {
	fmt.Println("🏥 Cluster Health Check")
	fmt.Println("=======================")

	// Node status
	nodes, err := clientset.CoreV1().Nodes().List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ Error listing nodes: %v\n", err)
		return
	}
	fmt.Printf("\n📦 Nodes (%d):\n", len(nodes.Items))
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "  NAME\tSTATUS\tVERSION\tAGE")
	for _, node := range nodes.Items {
		status := "❌ NotReady"
		for _, cond := range node.Status.Conditions {
			if cond.Type == "Ready" && cond.Status == "True" {
				status = "✅ Ready"
			}
		}
		fmt.Fprintf(w, "  %s\t%s\t%s\t%s\n",
			node.Name, status, node.Status.NodeInfo.KubeletVersion, formatAge(node.CreationTimestamp))
	}
	w.Flush()

	// Pod status
	pods, err := clientset.CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ Error listing pods: %v\n", err)
		return
	}

	running, pending, failed, other := 0, 0, 0, 0
	for _, pod := range pods.Items {
		switch pod.Status.Phase {
		case corev1.PodRunning:
			running++
		case corev1.PodPending:
			pending++
		case corev1.PodFailed:
			failed++
		default:
			other++
		}
	}
	fmt.Printf("\n📋 Pods (total: %d):\n", len(pods.Items))
	fmt.Printf("  ✅ Running: %d  ⏳ Pending: %d  ❌ Failed: %d  ❓ Other: %d\n", running, pending, failed, other)

	if failed > 0 {
		fmt.Println("\n  Failed pods:")
		for _, pod := range pods.Items {
			if pod.Status.Phase == corev1.PodFailed {
				fmt.Printf("    - %s/%s (reason: %s)\n", pod.Namespace, pod.Name, pod.Status.Reason)
			}
		}
	}

	// High restart count
	restartThreshold := int32(5)
	fmt.Printf("\n🔄 Pods with high restarts (≥%d):\n", restartThreshold)
	foundHighRestarts := false
	for _, pod := range pods.Items {
		for _, cs := range pod.Status.ContainerStatuses {
			if cs.RestartCount >= restartThreshold {
				fmt.Printf("  ⚠️  %s/%s → %s: %d restarts\n", pod.Namespace, pod.Name, cs.Name, cs.RestartCount)
				foundHighRestarts = true
			}
		}
	}
	if !foundHighRestarts {
		fmt.Println("  ✅ No pods with high restart count")
	}

	// Deployment status
	deployments, err := clientset.AppsV1().Deployments(ns).List(context.Background(), metav1.ListOptions{})
	if err == nil && len(deployments.Items) > 0 {
		fmt.Printf("\n🚀 Deployments (%d):\n", len(deployments.Items))
		w2 := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w2, "  NAMESPACE\tNAME\tREADY\tUP-TO-DATE\tAVAILABLE")
		for _, d := range deployments.Items {
			ready := "✅"
			if d.Status.ReadyReplicas < d.Status.Replicas {
				ready = "⚠️ "
			}
			fmt.Fprintf(w2, "  %s\t%s\t%s %d/%d\t%d\t%d\n",
				d.Namespace, d.Name, ready,
				d.Status.ReadyReplicas, d.Status.Replicas,
				d.Status.UpdatedReplicas, d.Status.AvailableReplicas)
		}
		w2.Flush()
	}

	// Recent warning events
	events, err := clientset.CoreV1().Events(ns).List(context.Background(), metav1.ListOptions{
		FieldSelector: "type=Warning",
	})
	if err == nil && len(events.Items) > 0 {
		fmt.Printf("\n⚠️  Recent Warnings (%d):\n", len(events.Items))
		for _, ev := range events.Items {
			fmt.Printf("  - [%s/%s] %s: %s\n", ev.Namespace, ev.InvolvedObject.Name, ev.Reason, ev.Message)
		}
	} else if err == nil {
		fmt.Println("\n✅ No recent warning events")
	}

	fmt.Println()
	fmt.Println("=======================")
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
