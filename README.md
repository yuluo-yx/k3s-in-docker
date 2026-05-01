# k3s-in-docker

用 Docker 快速启动一个 k3s（轻量级 Kubernetes）集群，主要用于本地开发和服务测试。

```shell
alias mk=make

# k3s.local.Dockerfile 演示，运行之前查看 k3s-bin/README.md.
mk build-local

cd app && mk deploy

# mk deploy 运行完成执行
mk curl
```
