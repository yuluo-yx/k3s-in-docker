OUTPUT_DIR = _output
BINS = port-forward get-ns get kubeconfig pod-logs health

.PHONY: all
all: $(BINS) ## 构建所有工具

.PHONY: port-forward
port-forward: ## 构建端口转发工具
	go build -o $(OUTPUT_DIR)/port-forward ./port-forward

.PHONY: get-ns
get-ns: ## 构建命名空间查询工具
	go build -o $(OUTPUT_DIR)/get-ns ./get-ns

.PHONY: get
get: ## 构建资源查询工具
	go build -o $(OUTPUT_DIR)/get ./get

.PHONY: kubeconfig
kubeconfig: ## 构建 kubeconfig 提取工具
	go build -o $(OUTPUT_DIR)/kubeconfig ./kubeconfig

.PHONY: pod-logs
pod-logs: ## 构建 Pod 日志查看工具
	go build -o $(OUTPUT_DIR)/pod-logs ./pod-logs

.PHONY: health
health: ## 构建集群健康检查工具
	go build -o $(OUTPUT_DIR)/health ./health

.PHONY: clean
clean: ## 清理所有构建产物
	rm -rf $(OUTPUT_DIR)

.PHONY: help
help: ## 显示帮助信息
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
