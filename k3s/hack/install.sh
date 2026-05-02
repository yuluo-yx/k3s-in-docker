#!/bin/bash

set -ex

modules="br_netfilter overlay"
missing_mods=""

for mod in $modules; do
    if ! lsmod | grep -qw "^$mod"; then
        missing_mods="$mod $missing_mods"
    fi
done

if [ -n "$missing_mods" ]; then
    echo "WARN: The following kernel modules are not visible in the container: $missing_mods"
    echo "WARN: Continue startup; Docker/OrbStack may provide the required kernel features through the host VM."
fi

sh /bin/cgroup_pre_detect.sh
sh /bin/iptables_pre_detect.sh

# 在 mac orbstack 运行时，kubelet 报错 “error mounting "proc" to rootfs at "/proc" ... rootfs/proc: read-only file system” runc overlayfs 兼容性问题
exec /bin/k3s server --snapshotter native --disable metrics-server --disable-cloud-controller --disable-network-policy
