ARG TARGETARCH

FROM registry.cn-hangzhou.aliyuncs.com/aliyun_doker_hub/linux_${TARGETARCH}_alpine:3.20 AS downloader
ARG TARGETARCH

# https://github.com/k3s-io/k3s/releases/download/v1.35.4%2Bk3s1/k3s-airgap-images-${TARGETARCH}.tar.zst
# https://github.com/k3s-io/k3s/releases/download/v1.35.4%2Bk3s1/k3s-airgap-images-arm64.tar.zst
RUN wget -O /tmp/k3s-airgap-images-${TARGETARCH}.tar.zst \
        https://github.com/k3s-io/k3s/releases/download/v1.35.4%2Bk3s1/k3s-airgap-images-${TARGETARCH}.tar.zst

FROM registry.cn-hangzhou.aliyuncs.com/aliyun_doker_hub/linux_${TARGETARCH}_k3s:v1.35.4-k3s1

COPY --from=downloader /tmp/k3s-airgap-images-${TARGETARCH}.tar.zst /var/lib/rancher/k3s/agent/images/

COPY k3s/hack/cgroup_pre_detect.sh /bin/cgroup_pre_detect.sh
COPY k3s/hack/iptables_pre_detect.sh /bin/iptables_pre_detect.sh
COPY k3s/hack/install.sh /bin/install.sh

RUN chmod +x /bin/cgroup_pre_detect.sh \
        && chmod +x /bin/iptables_pre_detect.sh \
        && chmod +x /bin/install.sh

ENV PATH=/var/lib/rancher/k3s/data/cni:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/bin/aux \
    LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai

ENTRYPOINT ["sh"]
CMD ["/bin/install.sh"]
