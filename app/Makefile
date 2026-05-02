K3S_SERVER_NAME ?= nginx-k3s-server
K3S_DATA_DIR ?= /tmp/$(K3S_SERVER_NAME)
K3S_IMAGE ?= registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s:latest
K3S_ENHANCE_IMAGE ?= registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s:enhance
NginxPort ?= 58080
NginxNodePort ?= 31090

.PHONY: deploy
deploy: ## 部署 nginx app 到 k3s
	chmod +x start.sh
	K3S_IMAGE=$(K3S_IMAGE) K3SPort=6443 K3S_DATA_DIR=$(K3S_DATA_DIR) NginxPort=$(NginxPort) NginxNodePort=$(NginxNodePort) zsh start.sh

.PHONY: deploy-enhance
deploy-enhance: ## 使用增强镜像部署 nginx app 到 k3s
	chmod +x start.sh
	K3S_IMAGE=$(K3S_ENHANCE_IMAGE) K3SPort=6443 K3S_DATA_DIR=$(K3S_DATA_DIR) NginxPort=$(NginxPort) NginxNodePort=$(NginxNodePort) zsh start.sh

.PHONY: shell
shell: ## 进入 k3s 容器，优先使用 zsh，其次 bash/sh
	docker exec -it $(K3S_SERVER_NAME) sh -lc 'exec "$$(command -v zsh || command -v bash || command -v sh)"'

.PHONY: curl
curl: ## 测试 nginx 服务
	curl -s http://localhost:$(NginxPort)/

.PHONY: remove
remove: ## 删除 k3s 容器
	docker rm -f $(K3S_SERVER_NAME)

.PHONY: help
help: ## 显示帮助信息
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
