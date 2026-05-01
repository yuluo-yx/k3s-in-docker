#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE=${IMAGE:-registry.cn-hangzhou.aliyuncs.com/yuluo-yx/k3s}
TAG=${TAG:-latest}
PLATFORM=${PLATFORM:-}  # 默认空=当前架构; 多架构如 "linux/amd64,linux/arm64"
PUSH=${PUSH:-false}
DRIVER=${DRIVER:-docker-container}  # docker-container 支持多架构; 也可用 docker
IMAGE_REF_SAFE=${IMAGE//\//_}
OCI_OUTPUT=${OCI_OUTPUT:-${PROJECT_DIR}/_output/${IMAGE_REF_SAFE}_${TAG}.oci.tar}

# 检测当前架构
ARCH=$(uname -m)
case ${ARCH} in
  x86_64|amd64)  TARGETARCH="amd64" ;;
  aarch64|arm64) TARGETARCH="arm64" ;;
  *)       echo "❌ Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

BUILDKIT_IMAGE=${BUILDKIT_IMAGE:-registry.cn-hangzhou.aliyuncs.com/aliyun_doker_hub/linux_${TARGETARCH}_buildkit:buildx-stable-1}

BUILDER=k3s-builder

# 创建或复用 buildx builder
if ! docker buildx inspect ${BUILDER} >/dev/null 2>&1; then
  echo "🔧 Creating buildx builder: ${BUILDER} (image=${BUILDKIT_IMAGE})"
  docker buildx create \
    --name ${BUILDER} \
    --driver ${DRIVER} \
    --driver-opt image=${BUILDKIT_IMAGE} \
    --config ${SCRIPT_DIR}/buildkitd.toml \
    --use
else
  docker buildx use ${BUILDER}
fi

# 构建参数使用数组，避免路径或镜像名中出现特殊字符时被 shell 拆分。
BUILD_ARGS=(
  --builder "${BUILDER}"
  -f "${PROJECT_DIR}/k3s.Dockerfile"
  -t "${IMAGE}:${TAG}"
)

if [[ -n "${PLATFORM}" ]]; then
  echo "🔨 Building multi-arch image: ${IMAGE}:${TAG} (platforms=${PLATFORM})"
  BUILD_ARGS+=(--platform "${PLATFORM}")
  if [[ "${PUSH}" == "true" ]]; then
    BUILD_ARGS+=(--push)
  else
    mkdir -p "$(dirname "${OCI_OUTPUT}")"
    BUILD_ARGS+=(--output "type=oci,dest=${OCI_OUTPUT}")
    echo "📦 Multi-arch local output: ${OCI_OUTPUT}"
  fi
else
  echo "🔨 Building image: ${IMAGE}:${TAG} (native arch=${TARGETARCH})"
  BUILD_ARGS+=(--load)
fi

docker buildx build "${BUILD_ARGS[@]}" "${PROJECT_DIR}"

echo "✅ Done: ${IMAGE}:${TAG}"
