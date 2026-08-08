# k3s 实例

## 简介

本目录统一管理项目中的独立 k3s 实例。每个实例使用独立容器、宿主端口和 Docker named volume。

named volume 可避免 macOS VirtioFS 与 containerd native snapshotter 组合产生磁盘统计错误。删除容器时默认保留数据卷。

## 实例列表

| 实例 | API 端口 | 应用端口 | 数据卷 |
| --- | ---: | ---: | --- |
| `nginx-k3s-server` | `6443` | `58080` | `nginx-k3s-server-data` |
| `kueue-k3s-server`（增强镜像） | `6444` | 无 | `kueue-k3s-server-data` |

## 常用命令

```shell
make -C servers/nginx-k3s-server deploy
make -C servers/kueue-k3s-server deploy
make -C servers status
```

进入实例：

```shell
make -C servers/nginx-k3s-server shell
make -C servers/kueue-k3s-server shell
```

删除容器但保留数据卷：

```shell
make -C servers/nginx-k3s-server remove
make -C servers/kueue-k3s-server remove
```

## 版本来源

- k3s 镜像版本：`v1.35.4+k3s1`，由项目 Dockerfile 固定。
- Kueue 版本：`v0.19.0`，由 Kueue 实例 Makefile 固定。
- Kueue 安装方式：[Kueue 官方安装文档](https://kueue.sigs.k8s.io/docs/installation/)。

版本信息最后核验于 2026-08-08。
