package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/portforward"
	"k8s.io/client-go/transport/spdy"
)

func main() {
	forward := flag.String("forward", "", "port forward spec, e.g. 8080:80 (localPort:remotePort)")
	kubeconfig := flag.String("kubeconfig", defaultKubeconfig(), "path to kubeconfig file")
	namespace := flag.String("namespace", "default", "kubernetes namespace")
	flag.Parse()

	if *forward == "" {
		fmt.Fprintln(os.Stderr, "Error: --forward is required, e.g. --forward=8080:80")
		flag.Usage()
		os.Exit(1)
	}

	localPort, remotePort := splitLast(*forward, ":")
	if remotePort == "" {
		fmt.Fprintln(os.Stderr, "Error: invalid forward spec, use localPort:remotePort, e.g. 8080:80")
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

	podName, err := findRunningPod(clientset, *namespace)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error finding pod: %v\n", err)
		os.Exit(1)
	}

	transport, upgrader, err := spdy.RoundTripperFor(config)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating SPDY transport: %v\n", err)
		os.Exit(1)
	}

	serverURL, err := url.Parse(config.Host)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing API server URL %q: %v\n", config.Host, err)
		os.Exit(1)
	}
	serverURL.Path = fmt.Sprintf("/api/v1/namespaces/%s/pods/%s/portforward", *namespace, podName)
	serverURL.RawQuery = ""
	serverURL.Fragment = ""

	dialer := spdy.NewDialer(upgrader, &http.Client{Transport: transport}, "POST", serverURL)

	readyChan := make(chan struct{}, 1)
	stopChan := make(chan struct{}, 1)
	var stopOnce sync.Once
	stopForward := func() {
		stopOnce.Do(func() {
			close(stopChan)
		})
	}

	ports := []string{fmt.Sprintf("%s:%s", localPort, remotePort)}

	pf, err := portforward.New(dialer, ports, readyChan, stopChan, os.Stdout, os.Stderr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating port forwarder: %v\n", err)
		os.Exit(1)
	}

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Stop(sigChan)

	go func() {
		<-sigChan
		fmt.Println("\n🛑 Shutting down port forward...")
		stopForward()
	}()

	go func() {
		if err := pf.ForwardPorts(); err != nil {
			fmt.Fprintf(os.Stderr, "Error forwarding ports: %v\n", err)
		}
		stopForward()
	}()

	select {
	case <-readyChan:
		fmt.Printf("✅ Port forwarding active: localhost:%s -> pod/%s:%s (ns=%s)\n", localPort, podName, remotePort, *namespace)
	case <-stopChan:
		fmt.Fprintln(os.Stderr, "Port forward stopped")
		os.Exit(1)
	}

	<-stopChan
}

func defaultKubeconfig() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".kube", "k3s", "kubeconfig")
}

func splitLast(s, sep string) (string, string) {
	for i := len(s) - 1; i >= 0; i-- {
		if string(s[i]) == sep {
			return s[:i], s[i+1:]
		}
	}
	return s, ""
}

func findRunningPod(clientset *kubernetes.Clientset, ns string) (string, error) {
	pods, err := clientset.CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		return "", fmt.Errorf("listing pods in namespace %s: %w", ns, err)
	}
	for _, pod := range pods.Items {
		if pod.Status.Phase == "Running" {
			return pod.Name, nil
		}
	}
	return "", fmt.Errorf("no running pods found in namespace %s", ns)
}
