# k3s-in-docker

本项目使用 Docker 启动独立的 k3s 集群，适用于本地开发和服务测试。仓库内置 nginx 与 Kueue 两套实例配置。

## 目录结构

- `k3s/basic/`：基础镜像 Dockerfile。
- `k3s/enhance/`：包含常用运维工具的增强镜像。
- `k3s/hack/`：镜像构建、k3s 启动和宿主兼容性检测脚本。
- `k3s/bin/`：k3s airgap 镜像包。
- `servers/`：全部 k3s 实例的配置、清单和统一操作入口。
- `bin/`：访问 k3s 的 Go 命令行工具。

## 快速开始

先按照 [k3s/bin/README.md](k3s/bin/README.md) 准备当前架构的 airgap 包，再构建基础镜像：

```shell
make build-local
```

启动 nginx 实例：

```shell
make deploy-nginx
curl http://localhost:58080/
```

启动 Kueue 实例：

```shell
make build-enhance
make deploy-kueue
make -C servers/kueue-k3s-server smoke-test
```

统一检查两个实例：

```shell
make status-servers
```

详细说明参见 [servers/README.md](servers/README.md)。

## 增强镜像

增强镜像包含 curl、jq、vim、OpenSSL、SSH、Zsh、Bash 和 typo 等工具：

```shell
make build-enhance
make -C servers/nginx-k3s-server deploy-enhance
make -C servers/nginx-k3s-server shell
```
