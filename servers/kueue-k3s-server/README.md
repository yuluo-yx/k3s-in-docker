# kueue-k3s-server

## 简介

本实例运行独立 k3s 集群，并安装 Kubernetes 原生作业队列 Kueue。实例使用 Kueue `v0.19.0`。

容器默认使用增强镜像。镜像包含 vim、typo、curl、jq、OpenSSL、SSH、Zsh 和 Bash 等常用工具。Zsh 提供彩色双行提示符、命令高亮、自动建议和 kubectl 常用别名。

Kueue 要求 Kubernetes `v1.29` 或更高版本。本项目的 k3s `v1.35.4+k3s1` 满足要求。

## 启动

```shell
make -C ../.. build-enhance
make deploy
```

该命令执行以下操作：

1. 启动 `kueue-k3s-server`。
2. 从 Kueue 官方发布地址安装固定版本清单。
3. 创建默认 ResourceFlavor、ClusterQueue 和 LocalQueue。

k3s API 地址为 `https://localhost:6444`。

## 远程部署与访问

在运行 Docker 的服务器上准备与服务器架构匹配的 airgap 包。启动时，将客户端访问的 IP 地址或域名加入 API 证书：

```shell
make deploy K3S_TLS_SAN=<server-ip-or-dns> K3S_API_PORT=6444 K3S_CPUS=1 K3S_MEMORY=2g
```

`K3S_CPUS` 和 `K3S_MEMORY` 可限制整个 k3s 容器的 CPU 和内存，包含控制平面及全部 Pod。示例上限为 1 核 CPU、2 GiB 内存，实际值需要根据宿主机余量和计划负载调整；两项留空时沿用 Docker 默认值。Docker 的限制不会自动缩减 Kueue 队列配额，应同时调整队列配置。

`K3S_TLS_SAN`、`K3S_CPUS` 和 `K3S_MEMORY` 仅在创建容器时传入。已有容器需要保留数据卷并重新创建，才能应用新的参数。远程访问还需要服务器防火墙允许客户端连接指定 API 端口。

将 kubeconfig 保存到服务器上的受限文件，再复制到客户端：

```shell
umask 077
docker exec kueue-k3s-server cat /etc/rancher/k3s/k3s.yaml > kubeconfig.yaml
scp kubeconfig.yaml <client-host>:<client-kubeconfig-path>
```

在客户端将 kubeconfig 中的 `server` 改为 `https://<server-ip-or-dns>:6444`，保留 CA 和客户端证书。kubeconfig 包含集群管理员凭据，不应提交到 Git。客户端配置了 HTTP 代理时，将服务器地址加入 `NO_PROXY` 和 `no_proxy`，再执行：

```shell
kubectl --kubeconfig <client-kubeconfig-path> get nodes
```

## 存储与 CNI 故障排查

k3s 默认使用 Flannel。节点出现 `NetworkPluginNotReady` 时，先检查数据挂载和 CNI 配置：

```shell
docker inspect kueue-k3s-server --format '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{println}}{{end}}'
docker exec kueue-k3s-server ls -l /var/lib/rancher/k3s/agent/etc/cni/net.d
docker exec kueue-k3s-server kubectl describe node kueue-k3s-server
```

不要将 `/var/lib/rancher/k3s` 挂载到宿主机的 `/tmp`、`/var/tmp`、`/run` 或 `/dev/shm`。这些目录可能被定期清理或在重启时清空，导致 CNI 配置或其他集群文件丢失。启动脚本会拒绝复用此类旧容器。

旧集群需要保留数据时，先停止容器并备份数据目录，再迁移到持久化卷；确认迁移成功前保留原目录和容器配置。需要全新集群时，备份后删除旧容器，使用新的数据卷启动。删除容器不会修复已经丢失的集群文件，也不会自动迁移旧数据。

## 验证

提交一个受 Kueue 管理的示例 Job：

```shell
make smoke-test
make status
```

示例 Job 使用 k3s airgap 包内置镜像，不依赖外部镜像仓库。

## 三任务串行调度演示

π 计算示例同时提交 3 个 Job。每个 Job 请求 `3 CPU`，ClusterQueue 的 CPU 配额为 `4`。因此，Kueue 每次只准入 1 个 Job，其余 Job 等待配额释放。

```shell
make pi-demo
```

命令先输出初始调度状态，再等待全部 Job 完成。最后会输出 3 个 π 计算结果。

单独查看调度对象：

```shell
docker exec kueue-k3s-server kubectl -n default get workload
docker exec kueue-k3s-server kubectl -n default get job,pod -l demo=kueue-pi
```

删除演示任务：

```shell
make pi-clean
```

## 运维

```shell
make shell
make remove
```

`make remove` 只删除容器。数据保留在 `kueue-k3s-server-data` 卷中。

## 参考资料

- [Kueue 安装文档](https://kueue.sigs.k8s.io/docs/installation/)
- [Kueue 快速开始](https://kueue.sigs.k8s.io/docs/getting-started/quick-start/)

资料最后核验于 2026-08-08。
