ARG TARGETARCH

FROM registry.cn-hangzhou.aliyuncs.com/aliyun_doker_hub/linux_${TARGETARCH}_alpine:3.20 AS apk-bootstrap
ARG TARGETARCH

FROM registry.cn-hangzhou.aliyuncs.com/aliyun_doker_hub/linux_${TARGETARCH}_k3s:v1.35.4-k3s1
ARG TARGETARCH
ARG TYPO_VERSION=v1.1.0

# 增强版沿用本地 airgap 包，避免构建时重复下载 k3s 镜像包。
COPY k3s/bin/k3s-airgap-images-${TARGETARCH}.tar.zst /var/lib/rancher/k3s/agent/images/

# k3s 基础镜像不带 apk，这里只引入 Alpine 的 apk 运行依赖，再在最终镜像安装运维工具。
COPY --from=apk-bootstrap /sbin/apk /sbin/apk
COPY --from=apk-bootstrap /etc/apk /etc/apk
COPY --from=apk-bootstrap /etc/ssl /etc/ssl
COPY --from=apk-bootstrap /lib/ /lib/

RUN apk add --initdb --no-cache \
        bash \
        bind-tools \
        busybox-extras \
        ca-certificates \
        curl \
        iproute2 \
        iputils \
        jq \
        less \
        openssh-client \
        openssl \
        tzdata \
        vim \
        zsh \
    && update-ca-certificates \
    && mkdir -p /etc/profile.d /root/.kube /var/log \
    && if [ -f /etc/passwd ]; then \
        sed -i 's#^\(root:[^:]*:0:0:[^:]*:\)[^:]*:[^:]*#\1/root:/bin/zsh#' /etc/passwd; \
    fi

RUN set -eux; \
    curl -fsSL https://raw.githubusercontent.com/yuluo-yx/use/master/vim/simple._vimrc >> /root/.vimrc; \
    typo_asset="typo-linux-${TARGETARCH}"; \
    curl -fsSL -o /tmp/typo-checksums.txt "https://github.com/yuluo-yx/typo/releases/download/${TYPO_VERSION}/checksums.txt"; \
    curl -fsSL -o "/tmp/${typo_asset}" "https://github.com/yuluo-yx/typo/releases/download/${TYPO_VERSION}/${typo_asset}"; \
    cd /tmp; \
    grep "  ${typo_asset}$" typo-checksums.txt | sha256sum -c -; \
    mkdir -p /usr/local/bin; \
    cp "/tmp/${typo_asset}" /usr/local/bin/typo; \
    chmod 0755 /usr/local/bin/typo; \
    rm -f "/tmp/${typo_asset}" /tmp/typo-checksums.txt

COPY k3s/enhance/hack/profile.d/k3s-enhance.sh /etc/profile.d/k3s-enhance.sh
COPY k3s/enhance/hack/root/.bashrc /root/.bashrc
COPY k3s/enhance/hack/root/.zshrc /root/.zshrc

COPY k3s/hack/cgroup_pre_detect.sh /bin/cgroup_pre_detect.sh
COPY k3s/hack/iptables_pre_detect.sh /bin/iptables_pre_detect.sh
COPY k3s/hack/install.sh /bin/install.sh

RUN chmod +x /bin/cgroup_pre_detect.sh \
        && chmod +x /bin/iptables_pre_detect.sh \
        && chmod +x /bin/install.sh

ENV PATH=/var/lib/rancher/k3s/data/cni:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/bin/aux \
    LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai \
    HOME=/root \
    SHELL=/bin/zsh

ENTRYPOINT ["/bin/zsh", "-lc"]
CMD ["/bin/install.sh"]
