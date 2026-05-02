# Demo

由当前的 k3s 镜像启动一个 nginx app。

```shell
make deploy

make curl

# 使用增强镜像部署，容器内包含 curl/jq/vim/openssl/ssh/zsh/bash/typo 等运维工具。
make deploy-enhance

# 进入容器，优先使用 zsh，其次 bash/sh。
make shell

make remove
```
