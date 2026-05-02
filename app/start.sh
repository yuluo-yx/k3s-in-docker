#!/bin/zsh

set -e

K3S_SERVER_NAME=nginx-k3s-server
K3S_IMAGE=${K3S_IMAGE:-registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s:latest}
K3SPort=${K3SPort:-6443}
NginxPort=${NginxPort:-58080}
NginxNodePort=${NginxNodePort:-31090}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K3S_DATA_DIR=${K3S_DATA_DIR:-/tmp/${K3S_SERVER_NAME}}
ARCH=$(uname -m)

# 统一架构命名
case ${ARCH} in
  x86_64|amd64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac

function render() {
  sed "s|{{\.ARCH}}|${ARCH}|g" "$1"
}

function start() {
  echo "🚀 Starting k3s container (ARCH=${ARCH}, IMAGE=${K3S_IMAGE})..."
  docker run --privileged --restart=always \
    --name ${K3S_SERVER_NAME} \
    --hostname ${K3S_SERVER_NAME} \
    -p ${K3SPort}:6443 \
    -p ${NginxPort}:${NginxNodePort} \
    -v ${K3S_DATA_DIR}:/var/lib/rancher/k3s \
    -v ${PROJECT_DIR}/k3s/bin:/var/lib/rancher/k3s/agent/images \
    -v ${SCRIPT_DIR}/assets:/var/lib/rancher/k3s/app/assets \
    -d ${K3S_IMAGE}
}

function check() {
  echo "⏳ Waiting for k3s to be ready..."
  ready=0
  for i in {1..30}; do
      if docker exec ${K3S_SERVER_NAME} kubectl get ns >/dev/null 2>&1; then
          echo "✅ k3s is ready!"
          ready=1
          break
      else
          echo "  Waiting... ($i/30)"
          sleep 2
      fi
  done

  if [[ $ready -eq 0 ]]; then
      echo "❌ k3s failed to start!"
      docker logs ${K3S_SERVER_NAME}
      exit 1
  fi
}

function deploy() {
  echo "📦 Deploying nginx app to k3s (ARCH=${ARCH})..."
  render ${SCRIPT_DIR}/nginx-ns.yml | docker exec -i ${K3S_SERVER_NAME} kubectl apply -f -
  render ${SCRIPT_DIR}/nginx-cm.yml | docker exec -i ${K3S_SERVER_NAME} kubectl apply -f -
  render ${SCRIPT_DIR}/nginx-deployment.yml | docker exec -i ${K3S_SERVER_NAME} kubectl apply -f -
  render ${SCRIPT_DIR}/nginx-svc.yml | docker exec -i ${K3S_SERVER_NAME} kubectl apply -f -
}

function check-nginx() {
  echo "⏳ Waiting for nginx deployment to be ready..."
  ready=0
  for i in {1..30}; do
      if docker exec ${K3S_SERVER_NAME} kubectl -n nginx rollout status deployment/nginx-deployment1 --timeout=5s >/dev/null 2>&1; then
          echo "✅ Nginx deployment is ready!"
          ready=1
          break
      else
          echo "  Waiting for nginx... ($i/30)"
          sleep 3
      fi
  done

  if [[ $ready -eq 0 ]]; then
      echo "❌ Nginx deployment failed!"
      docker exec ${K3S_SERVER_NAME} kubectl -n nginx describe deployment nginx-deployment1
      exit 1
  fi

  echo ""
  echo "🎉 Nginx app is running!"
  echo "   Access via: curl http://localhost:${NginxPort}/"
}

start
check
deploy
check-nginx
