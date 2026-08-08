#!/usr/bin/env bash

set -Eeuo pipefail

: "${K3S_SERVER_NAME:?必须设置 K3S_SERVER_NAME}"
: "${K3S_API_PORT:?必须设置 K3S_API_PORT}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K3S_IMAGE="${K3S_IMAGE:-registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s:latest}"
K3S_DATA_VOLUME="${K3S_DATA_VOLUME:-${K3S_SERVER_NAME}-data}"

wait_for_ready() {
  local ready=""

  echo "等待 ${K3S_SERVER_NAME} 节点就绪。"
  for _ in $(seq 1 60); do
    ready="$(docker exec "${K3S_SERVER_NAME}" kubectl get node "${K3S_SERVER_NAME}" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "${ready}" == "True" ]]; then
      echo "${K3S_SERVER_NAME} 已就绪。"
      return 0
    fi
    sleep 2
  done

  echo "${K3S_SERVER_NAME} 未在 120 秒内就绪。" >&2
  docker logs --tail 200 "${K3S_SERVER_NAME}" >&2
  return 1
}

if docker inspect "${K3S_SERVER_NAME}" >/dev/null 2>&1; then
  if [[ "$(docker inspect -f '{{.State.Running}}' "${K3S_SERVER_NAME}")" != "true" ]]; then
    docker start "${K3S_SERVER_NAME}" >/dev/null
  fi
  wait_for_ready
  exit 0
fi

docker volume create "${K3S_DATA_VOLUME}" >/dev/null

run_args=(
  run
  --privileged
  --restart=always
  --name "${K3S_SERVER_NAME}"
  --hostname "${K3S_SERVER_NAME}"
  -p "${K3S_API_PORT}:6443"
  -v "${K3S_DATA_VOLUME}:/var/lib/rancher/k3s"
  -v "${PROJECT_DIR}/k3s/bin:/var/lib/rancher/k3s/agent/images"
)

if [[ -n "${K3S_NODE_PORT_MAPPING:-}" ]]; then
  run_args+=(-p "${K3S_NODE_PORT_MAPPING}")
fi

if [[ -n "${K3S_ASSETS_DIR:-}" ]]; then
  run_args+=(-v "${K3S_ASSETS_DIR}:/var/lib/rancher/k3s/app/assets")
fi

echo "启动 ${K3S_SERVER_NAME}，镜像为 ${K3S_IMAGE}。"
docker "${run_args[@]}" -d "${K3S_IMAGE}" >/dev/null
wait_for_ready
