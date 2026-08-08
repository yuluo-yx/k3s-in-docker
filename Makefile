IMAGE ?= registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s
TAG  ?= latest
ENHANCE_TAG ?= enhance

.PHONY: deploy-nginx
deploy-nginx: ## 启动 nginx-k3s-server 并部署 nginx
	$(MAKE) -C servers/nginx-k3s-server deploy

.PHONY: deploy-kueue
deploy-kueue: ## 启动 kueue-k3s-server 并安装 Kueue
	$(MAKE) -C servers/kueue-k3s-server deploy

.PHONY: status-servers
status-servers: ## 检查全部 k3s server
	$(MAKE) -C servers status

.PHONY: remove-nginx
remove-nginx: ## 删除 nginx-k3s-server，保留数据卷
	$(MAKE) -C servers/nginx-k3s-server remove

.PHONY: remove-kueue
remove-kueue: ## 删除 kueue-k3s-server，保留数据卷
	$(MAKE) -C servers/kueue-k3s-server remove

.PHONY: build
build: ## 构建当前架构的 k3s 镜像
	bash k3s/hack/build.sh

.PHONY: build-local
build-local: ## 使用 k3s/bin 本地 airgap 包构建当前架构的 k3s 镜像
	@ARCH=$$(uname -m); \
	case "$${ARCH}" in \
	  x86_64|amd64) TARGETARCH=amd64 ;; \
	  aarch64|arm64) TARGETARCH=arm64 ;; \
	  *) echo "Unsupported architecture: $${ARCH}"; exit 1 ;; \
	esac; \
	AIRGAP_FILE="k3s/bin/k3s-airgap-images-$${TARGETARCH}.tar.zst"; \
	if [ ! -f "$${AIRGAP_FILE}" ]; then \
	  echo "Missing local airgap file: $${AIRGAP_FILE}"; \
	  exit 1; \
	fi; \
	docker buildx build --platform linux/$${TARGETARCH} -f k3s/basic/k3s.local.Dockerfile -t $(IMAGE):$(TAG) --load .

.PHONY: build-enhance
build-enhance: ## 使用本地 airgap 包构建带运维工具的增强镜像
	@ARCH=$$(uname -m); \
	case "$${ARCH}" in \
	  x86_64|amd64) TARGETARCH=amd64 ;; \
	  aarch64|arm64) TARGETARCH=arm64 ;; \
	  *) echo "Unsupported architecture: $${ARCH}"; exit 1 ;; \
	esac; \
	AIRGAP_FILE="k3s/bin/k3s-airgap-images-$${TARGETARCH}.tar.zst"; \
	if [ ! -f "$${AIRGAP_FILE}" ]; then \
	  echo "Missing local airgap file: $${AIRGAP_FILE}"; \
	  exit 1; \
	fi; \
	docker buildx build --platform linux/$${TARGETARCH} -f k3s/enhance/k3s.enhance.Dockerfile -t $(IMAGE):$(ENHANCE_TAG) --load .

.PHONY: build-multi
build-multi: ## 构建多架构镜像 (linux/amd64 + linux/arm64)
	PLATFORM=linux/amd64,linux/arm64 bash k3s/hack/build.sh

.PHONY: push
push: ## 构建多架构并推送
	PLATFORM=linux/amd64,linux/arm64 PUSH=true bash k3s/hack/build.sh

.PHONY: help
help: ## 显示帮助信息
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
