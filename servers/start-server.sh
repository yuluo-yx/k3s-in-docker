#!/usr/bin/env bash

set -Eeuo pipefail

: "${K3S_SERVER_NAME:?K3S_SERVER_NAME must be set}"
: "${K3S_API_PORT:?K3S_API_PORT must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K3S_IMAGE="${K3S_IMAGE:-registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s:latest}"
K3S_DATA_VOLUME="${K3S_DATA_VOLUME:-${K3S_SERVER_NAME}-data}"

wait_for_ready() {
  local ready=""

  echo "Waiting for node ${K3S_SERVER_NAME} to become Ready."
  for _ in $(seq 1 60); do
    ready="$(docker exec "${K3S_SERVER_NAME}" kubectl get node "${K3S_SERVER_NAME}" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "${ready}" == "True" ]]; then
      echo "Node ${K3S_SERVER_NAME} is Ready."
      return 0
    fi
    sleep 2
  done

  echo "Node ${K3S_SERVER_NAME} did not become Ready within 120 seconds." >&2
  docker logs --tail 200 "${K3S_SERVER_NAME}" >&2
  return 1
}

if docker inspect "${K3S_SERVER_NAME}" >/dev/null 2>&1; then
  data_source="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/rancher/k3s"}}{{if eq .Type "bind"}}{{.Source}}{{end}}{{end}}{{end}}' "${K3S_SERVER_NAME}")"
  # Temporary host directories can lose CNI configuration during automatic cleanup.
  case "${data_source}" in
    /tmp|/tmp/*|/var/tmp|/var/tmp/*|/run|/run/*|/var/run|/var/run/*|/dev/shm|/dev/shm/*)
      echo "Refusing to reuse ${K3S_SERVER_NAME}: k3s data is stored in temporary directory ${data_source}." >&2
      echo "Back up the cluster and recreate the container with persistent storage." >&2
      exit 1
      ;;
  esac
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

if [[ -n "${K3S_CPUS:-}" ]]; then
  run_args+=(--cpus "${K3S_CPUS}")
fi

if [[ -n "${K3S_MEMORY:-}" ]]; then
  run_args+=(--memory "${K3S_MEMORY}")
fi

if [[ -n "${K3S_TLS_SAN:-}" ]]; then
  run_args+=(-e "K3S_TLS_SAN=${K3S_TLS_SAN}")
fi

if [[ -n "${K3S_NODE_PORT_MAPPING:-}" ]]; then
  run_args+=(-p "${K3S_NODE_PORT_MAPPING}")
fi

if [[ -n "${K3S_ASSETS_DIR:-}" ]]; then
  run_args+=(-v "${K3S_ASSETS_DIR}:/var/lib/rancher/k3s/app/assets")
fi

echo "Starting ${K3S_SERVER_NAME} with image ${K3S_IMAGE}."
docker "${run_args[@]}" -d "${K3S_IMAGE}" >/dev/null
wait_for_ready
