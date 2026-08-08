.DEFAULT_GOAL := help

SERVER_NAME := kueue-k3s-server
SERVER_DIR := $(CURDIR)
SERVERS_DIR := $(abspath ..)
K3S_IMAGE ?= registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s:enhance
K3S_API_PORT ?= 6444
KUEUE_VERSION ?= v0.19.0
KUEUE_MANIFEST_URL := https://github.com/kubernetes-sigs/kueue/releases/download/$(KUEUE_VERSION)/manifests.yaml

.PHONY: deploy server install configure smoke-test pi-demo pi-clean status shell remove help

deploy: server install configure ## 启动实例、安装 Kueue 并配置队列

server: ## 启动 Kueue k3s 实例
	K3S_SERVER_NAME=$(SERVER_NAME) \
	K3S_API_PORT=$(K3S_API_PORT) \
	K3S_DATA_VOLUME=$(SERVER_NAME)-data \
	K3S_IMAGE=$(K3S_IMAGE) \
	bash $(SERVERS_DIR)/start-server.sh

install: ## 安装固定版本的 Kueue
	docker exec $(SERVER_NAME) kubectl apply --server-side -f $(KUEUE_MANIFEST_URL)
	docker exec $(SERVER_NAME) kubectl -n kueue-system wait \
		deployment/kueue-controller-manager \
		--for=condition=Available --timeout=300s

configure: ## 配置默认 ResourceFlavor、ClusterQueue 和 LocalQueue
	docker exec -i $(SERVER_NAME) kubectl apply -f - < $(SERVER_DIR)/manifests/queues.yaml
	docker exec $(SERVER_NAME) kubectl wait clusterqueue/default \
		--for=condition=Active --timeout=60s
	docker exec $(SERVER_NAME) kubectl -n default wait localqueue/default \
		--for=condition=Active --timeout=60s

smoke-test: ## 提交并验证一个受 Kueue 管理的 Job
	docker exec $(SERVER_NAME) kubectl -n default delete job/kueue-sample \
		--ignore-not-found --wait=true
	docker exec -i $(SERVER_NAME) kubectl apply -f - < $(SERVER_DIR)/manifests/sample-job.yaml
	docker exec $(SERVER_NAME) kubectl -n default wait job/kueue-sample \
		--for=condition=Complete --timeout=180s
	docker exec $(SERVER_NAME) kubectl -n default get workload,job,pod

pi-demo: pi-clean ## 提交 3 个计算 π 的 Job，演示 Kueue 串行准入
	docker exec -i $(SERVER_NAME) kubectl apply -f - < $(SERVER_DIR)/manifests/pi-jobs.yaml
	@sleep 3
	@echo "== 初始调度状态：1 个准入，2 个等待 =="
	@docker exec $(SERVER_NAME) kubectl -n default get workload | \
		awk 'NR == 1 || $$1 ~ /^job-pi-job-/'
	docker exec $(SERVER_NAME) kubectl -n default get job,pod -l demo=kueue-pi
	docker exec $(SERVER_NAME) kubectl -n default wait \
		--for=condition=Complete --timeout=180s \
		job/pi-job-1 job/pi-job-2 job/pi-job-3
	@echo "== 最终状态 =="
	@docker exec $(SERVER_NAME) kubectl -n default get workload | \
		awk 'NR == 1 || $$1 ~ /^job-pi-job-/'
	docker exec $(SERVER_NAME) kubectl -n default get job,pod -l demo=kueue-pi
	@for job in pi-job-1 pi-job-2 pi-job-3; do \
		echo "== $$job 日志 =="; \
		docker exec $(SERVER_NAME) kubectl -n default logs job/$$job; \
	done

pi-clean: ## 删除 π 计算演示的 3 个 Job
	docker exec $(SERVER_NAME) kubectl -n default delete \
		job/pi-job-1 job/pi-job-2 job/pi-job-3 \
		--ignore-not-found --wait=true

status: ## 检查 Kueue 实例
	@docker inspect $(SERVER_NAME) >/dev/null 2>&1 || { echo "容器不存在"; exit 1; }
	@docker ps --filter name=^/$(SERVER_NAME)$$ --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'
	docker exec $(SERVER_NAME) kubectl get nodes
	docker exec $(SERVER_NAME) kubectl -n kueue-system get deployment,pod
	docker exec $(SERVER_NAME) kubectl get clusterqueue,resourceflavor
	docker exec $(SERVER_NAME) kubectl -n default get localqueue,workload

shell: ## 进入实例
	docker exec -it $(SERVER_NAME) sh -lc 'exec "$$(command -v zsh || command -v bash || command -v sh)"'

remove: ## 删除容器并保留数据卷
	docker rm -f $(SERVER_NAME)

help: ## 显示帮助信息
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
