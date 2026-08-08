.DEFAULT_GOAL := help

SERVERS := nginx-k3s-server kueue-k3s-server

.PHONY: status help

status: ## 检查全部 k3s server
	@for server in $(SERVERS); do \
		echo "== $$server =="; \
		$(MAKE) --no-print-directory -C $$server status || true; \
	done

help: ## 显示帮助信息
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
