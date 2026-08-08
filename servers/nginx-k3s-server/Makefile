.DEFAULT_GOAL := help

SERVER_NAME := nginx-k3s-server
SERVER_DIR := $(CURDIR)
SERVERS_DIR := $(abspath ..)
K3S_IMAGE ?= registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s:latest
K3S_ENHANCE_IMAGE ?= registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s:enhance
K3S_API_PORT ?= 6443
NGINX_PORT ?= 58080
NGINX_NODE_PORT ?= 31090
NGINX_IMAGE ?= nginx:1.28-alpine

.PHONY: deploy deploy-enhance prepare-image server apply status curl shell remove help

deploy: prepare-image server apply ## 启动实例并部署 nginx

deploy-enhance: K3S_IMAGE=$(K3S_ENHANCE_IMAGE)
deploy-enhance: prepare-image server apply ## 使用增强镜像启动实例并部署 nginx

prepare-image: ## 准备可由 k3s 离线导入的 nginx 镜像
	@arch=$$(uname -m); \
	case "$$arch" in \
		x86_64|amd64) arch=amd64 ;; \
		aarch64|arm64) arch=arm64 ;; \
		*) echo "不支持的架构：$$arch"; exit 1 ;; \
	esac; \
	archive="$(abspath ../../k3s/bin)/nginx-1.28-alpine-$$arch.tar"; \
	if [ ! -s "$$archive" ]; then \
		docker image inspect $(NGINX_IMAGE) >/dev/null 2>&1 || docker pull $(NGINX_IMAGE); \
		docker save --output "$$archive" $(NGINX_IMAGE); \
	fi

server: ## 启动 nginx k3s 实例
	K3S_SERVER_NAME=$(SERVER_NAME) \
	K3S_API_PORT=$(K3S_API_PORT) \
	K3S_DATA_VOLUME=$(SERVER_NAME)-data \
	K3S_IMAGE=$(K3S_IMAGE) \
	K3S_NODE_PORT_MAPPING=$(NGINX_PORT):$(NGINX_NODE_PORT) \
	K3S_ASSETS_DIR=$(SERVER_DIR)/assets \
	bash $(SERVERS_DIR)/start-server.sh

apply: ## 应用 nginx 清单
	@arch=$$(uname -m); \
	case "$$arch" in \
		x86_64|amd64) arch=amd64 ;; \
		aarch64|arm64) arch=arm64 ;; \
		*) echo "不支持的架构：$$arch"; exit 1 ;; \
	esac; \
	for manifest in namespace configmap deployment service; do \
		sed -e "s|{{.ARCH}}|$$arch|g" \
			-e "s|{{.NODE_PORT}}|$(NGINX_NODE_PORT)|g" \
			"$(SERVER_DIR)/manifests/$$manifest.yaml" | \
			docker exec -i $(SERVER_NAME) kubectl apply -f -; \
	done
	docker exec $(SERVER_NAME) kubectl -n nginx rollout status deployment/nginx --timeout=180s

status: ## 检查 nginx 实例
	@docker inspect $(SERVER_NAME) >/dev/null 2>&1 || { echo "容器不存在"; exit 1; }
	@docker ps --filter name=^/$(SERVER_NAME)$$ --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'
	docker exec $(SERVER_NAME) kubectl get nodes
	docker exec $(SERVER_NAME) kubectl -n nginx get deployment,service,pod

curl: ## 请求 nginx 页面
	curl -fsS http://127.0.0.1:$(NGINX_PORT)/

shell: ## 进入实例
	docker exec -it $(SERVER_NAME) sh -lc 'exec "$$(command -v zsh || command -v bash || command -v sh)"'

remove: ## 删除容器并保留数据卷
	docker rm -f $(SERVER_NAME)

help: ## 显示帮助信息
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
