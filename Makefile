IMAGE ?= registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s
TAG  ?= latest

.PHONY: build
build: ## 构建当前架构的 k3s 镜像
	bash hack/build.sh

.PHONY: build-multi
build-multi: ## 构建多架构镜像 (linux/amd64 + linux/arm64)
	PLATFORM=linux/amd64,linux/arm64 bash hack/build.sh

.PHONY: push
push: ## 构建多架构并推送
	PLATFORM=linux/amd64,linux/arm64 PUSH=true bash hack/build.sh

.PHONY: help
help: ## 显示帮助信息
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
