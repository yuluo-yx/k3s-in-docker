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
