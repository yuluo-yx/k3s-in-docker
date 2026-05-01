ARG TARGETARCH

FROM registry.cn-hangzhou.aliyuncs.com/aliyun_doker_hub/linux_${TARGETARCH}_k3s:v1.35.4-k3s1
ARG TARGETARCH

# 从本地 copy k3s tar
COPY k3s-bin/k3s-airgap-images-${TARGETARCH}.tar.zst /var/lib/rancher/k3s/agent/images/

COPY hack/cgroup_pre_detect.sh /bin/cgroup_pre_detect.sh
COPY hack/iptables_pre_detect.sh /bin/iptables_pre_detect.sh
COPY hack/install.sh /bin/install.sh

RUN chmod +x /bin/cgroup_pre_detect.sh \
        && chmod +x /bin/iptables_pre_detect.sh \
        && chmod +x /bin/install.sh

ENV PATH=/var/lib/rancher/k3s/data/cni:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/bin/aux \
    LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai

ENTRYPOINT ["sh"]
CMD ["/bin/install.sh"]
