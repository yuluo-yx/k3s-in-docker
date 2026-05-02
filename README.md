# k3s-in-docker

用 Docker 快速启动一个 k3s（轻量级 Kubernetes）集群，主要用于本地开发和服务测试。

目录说明：

- `k3s/basic/`：基础镜像 Dockerfile，包括在线下载 airgap 包的 `k3s.Dockerfile` 和使用本地包的 `k3s.local.Dockerfile`。
- `k3s/enhance/`：增强镜像 Dockerfile 与 shell 定制，容器内包含常用运维工具、vim 配置、typo 命令纠错和 zsh/bash 配置。
- `k3s/hack/`：basic/enhance 共用的构建辅助、k3s 启动和宿主兼容性检测脚本。
- `k3s/bin/`：k3s airgap 镜像包目录，避免和根目录 Go 工具 `bin/` 混淆。

```shell
alias mk=make

# k3s/basic/k3s.local.Dockerfile 演示，运行之前查看 k3s/bin/README.md.
mk build-local

cd app && mk deploy

# mk deploy 运行完成执行
mk curl

# 构建带 curl/jq/vim/openssl/ssh/zsh/bash/typo 等运维工具的增强镜像
cd .. && mk build-enhance

# 使用增强镜像部署，并进入容器交互式排查
cd app && mk deploy-enhance
mk shell
```
