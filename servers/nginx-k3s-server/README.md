# nginx-k3s-server

## 简介

本实例在独立 k3s 集群中部署 nginx，用于验证节点、网络、存储和 NodePort。

启动流程会把 `nginx:1.28-alpine` 保存到本地镜像归档。k3s 从 airgap 目录导入该归档，避免运行时依赖外部镜像仓库。

## 启动

```shell
make deploy
make curl
```

默认访问地址为 `http://localhost:58080/`，k3s API 地址为 `https://localhost:6443`。

## 运维

```shell
make status
make shell
make remove
```

`make remove` 只删除容器。数据保留在 `nginx-k3s-server-data` 卷中。
