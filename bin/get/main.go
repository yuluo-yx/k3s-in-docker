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
	namespace := flag.String("namespace", "default", "kubernetes namespace")
	resourceType := flag.String("type", "", "resource type: pods/po, deployments/deploy, services/svc, configmaps/cm, nodes/no")
	allNamespaces := flag.Bool("all-namespaces", false, "list across all namespaces")
	showLabels := flag.Bool("show-labels", false, "show labels in output")
	flag.Parse()

	if *resourceType == "" {
		fmt.Fprintln(os.Stderr, "Error: --type is required (pods/po, deployments/deploy, services/svc, configmaps/cm, nodes/no)")
		flag.Usage()
		os.Exit(1)
	}

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
	if *allNamespaces {
		ns = ""
	}

	switch normalizeResourceType(*resourceType) {
	case "pods":
		listPods(clientset, ns, *showLabels)
	case "deployments":
		listDeployments(clientset, ns, *showLabels)
	case "services":
		listServices(clientset, ns, *showLabels)
	case "configmaps":
		listConfigMaps(clientset, ns, *showLabels)
	case "nodes":
		listNodes(clientset, *showLabels)
	default:
		fmt.Fprintf(os.Stderr, "Unknown resource type: %s\n", *resourceType)
		fmt.Fprintln(os.Stderr, "Supported: pods/po, deployments/deploy, services/svc, configmaps/cm, nodes/no")
		os.Exit(1)
	}
}

func normalizeResourceType(t string) string {
	switch t {
	case "po", "pod", "pods":
		return "pods"
	case "deploy", "deployment", "deployments":
		return "deployments"
	case "svc", "service", "services":
		return "services"
	case "cm", "configmap", "configmaps":
		return "configmaps"
	case "no", "node", "nodes":
		return "nodes"
	default:
		return t
	}
}

func listPods(clientset *kubernetes.Clientset, ns string, showLabels bool) {
	pods, err := clientset.CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error listing pods: %v\n", err)
		os.Exit(1)
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	if showLabels {
		fmt.Fprintln(w, "NAMESPACE\tNAME\tREADY\tSTATUS\tRESTARTS\tAGE\tLABELS")
	} else {
		fmt.Fprintln(w, "NAMESPACE\tNAME\tREADY\tSTATUS\tRESTARTS\tAGE")
	}
	for _, pod := range pods.Items {
		ready := 0
		for _, c := range pod.Status.ContainerStatuses {
			if c.Ready {
				ready++
			}
		}
		restarts := 0
		for _, c := range pod.Status.ContainerStatuses {
			restarts += int(c.RestartCount)
		}
		age := formatAge(pod.CreationTimestamp)
		if showLabels {
			fmt.Fprintf(w, "%s\t%s\t%d/%d\t%s\t%d\t%s\t%s\n",
				pod.Namespace, pod.Name, ready, len(pod.Spec.Containers),
				pod.Status.Phase, restarts, age, formatLabels(pod.Labels))
		} else {
			fmt.Fprintf(w, "%s\t%s\t%d/%d\t%s\t%d\t%s\n",
				pod.Namespace, pod.Name, ready, len(pod.Spec.Containers),
				pod.Status.Phase, restarts, age)
		}
	}
	w.Flush()
}

func listDeployments(clientset *kubernetes.Clientset, ns string, showLabels bool) {
	deployments, err := clientset.AppsV1().Deployments(ns).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error listing deployments: %v\n", err)
		os.Exit(1)
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	if showLabels {
		fmt.Fprintln(w, "NAMESPACE\tNAME\tREADY\tUP-TO-DATE\tAVAILABLE\tAGE\tLABELS")
	} else {
		fmt.Fprintln(w, "NAMESPACE\tNAME\tREADY\tUP-TO-DATE\tAVAILABLE\tAGE")
	}
	for _, d := range deployments.Items {
		age := formatAge(d.CreationTimestamp)
		if showLabels {
			fmt.Fprintf(w, "%s\t%s\t%d/%d\t%d\t%d\t%s\t%s\n",
				d.Namespace, d.Name, d.Status.ReadyReplicas, d.Status.Replicas,
				d.Status.UpdatedReplicas, d.Status.AvailableReplicas, age, formatLabels(d.Labels))
		} else {
			fmt.Fprintf(w, "%s\t%s\t%d/%d\t%d\t%d\t%s\n",
				d.Namespace, d.Name, d.Status.ReadyReplicas, d.Status.Replicas,
				d.Status.UpdatedReplicas, d.Status.AvailableReplicas, age)
		}
	}
	w.Flush()
}

func listServices(clientset *kubernetes.Clientset, ns string, showLabels bool) {
	services, err := clientset.CoreV1().Services(ns).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error listing services: %v\n", err)
		os.Exit(1)
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	if showLabels {
		fmt.Fprintln(w, "NAMESPACE\tNAME\tTYPE\tCLUSTER-IP\tPORT(S)\tAGE\tLABELS")
	} else {
		fmt.Fprintln(w, "NAMESPACE\tNAME\tTYPE\tCLUSTER-IP\tPORT(S)\tAGE")
	}
	for _, svc := range services.Items {
		ports := ""
		for i, p := range svc.Spec.Ports {
			if i > 0 {
				ports += ", "
			}
			ports += fmt.Sprintf("%d/%s", p.Port, p.Protocol)
		}
		age := formatAge(svc.CreationTimestamp)
		if showLabels {
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
				svc.Namespace, svc.Name, svc.Spec.Type, svc.Spec.ClusterIP, ports, age, formatLabels(svc.Labels))
		} else {
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\n",
				svc.Namespace, svc.Name, svc.Spec.Type, svc.Spec.ClusterIP, ports, age)
		}
	}
	w.Flush()
}

func listConfigMaps(clientset *kubernetes.Clientset, ns string, showLabels bool) {
	cms, err := clientset.CoreV1().ConfigMaps(ns).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error listing configmaps: %v\n", err)
		os.Exit(1)
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	if showLabels {
		fmt.Fprintln(w, "NAMESPACE\tNAME\tDATA\tAGE\tLABELS")
	} else {
		fmt.Fprintln(w, "NAMESPACE\tNAME\tDATA\tAGE")
	}
	for _, cm := range cms.Items {
		age := formatAge(cm.CreationTimestamp)
		dataCount := len(cm.Data)
		if showLabels {
			fmt.Fprintf(w, "%s\t%s\t%d\t%s\t%s\n",
				cm.Namespace, cm.Name, dataCount, age, formatLabels(cm.Labels))
		} else {
			fmt.Fprintf(w, "%s\t%s\t%d\t%s\n",
				cm.Namespace, cm.Name, dataCount, age)
		}
	}
	w.Flush()
}

func listNodes(clientset *kubernetes.Clientset, showLabels bool) {
	nodes, err := clientset.CoreV1().Nodes().List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error listing nodes: %v\n", err)
		os.Exit(1)
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	if showLabels {
		fmt.Fprintln(w, "NAME\tSTATUS\tAGE\tLABELS")
	} else {
		fmt.Fprintln(w, "NAME\tSTATUS\tAGE")
	}
	for _, node := range nodes.Items {
		status := "Unknown"
		for _, cond := range node.Status.Conditions {
			if cond.Type == "Ready" {
				if cond.Status == "True" {
					status = "Ready"
				} else {
					status = "NotReady"
				}
				break
			}
		}
		age := formatAge(node.CreationTimestamp)
		if showLabels {
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", node.Name, status, age, formatLabels(node.Labels))
		} else {
			fmt.Fprintf(w, "%s\t%s\t%s\n", node.Name, status, age)
		}
	}
	w.Flush()
}

func formatLabels(labels map[string]string) string {
	if len(labels) == 0 {
		return "<none>"
	}
	result := ""
	first := true
	for k, v := range labels {
		if !first {
			result += ","
		}
		result += k + "=" + v
		first = false
	}
	return result
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
