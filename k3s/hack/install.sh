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
# Source this script so IPTABLES_MODE reaches the k3s process.
. /bin/iptables_pre_detect.sh

# The native snapshotter avoids overlayfs mount issues under OrbStack.
set -- --snapshotter native --disable metrics-server --disable-cloud-controller --disable-network-policy

# k3s does not read K3S_TLS_SAN directly; pass it as a CLI option.
if [ -n "${K3S_TLS_SAN:-}" ]; then
    set -- "$@" --tls-san "${K3S_TLS_SAN}"
fi

exec /bin/k3s server "$@"
