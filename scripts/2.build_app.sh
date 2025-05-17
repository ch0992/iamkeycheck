#!/bin/bash
set -e

APP_NAME="iamkeycheck"
DEPLOYMENT_NAME="iamkeycheck-deployment"
DEFAULT_TAG="v1.0.0"
NERDCTL_NS="k8s.io"  # Colima K8s 네임스페이스

# .env에서 IMAGE_TAG, STAGE 읽기
env_file="../.env"
if [ -f "$env_file" ]; then
  set -a
  source "$env_file"
  set +a
fi
IMAGE_TAG="${IMAGE_TAG:-$DEFAULT_TAG}"
IMAGE_NAME="${APP_NAME}:${IMAGE_TAG}"

if nerdctl -n $NERDCTL_NS images | awk 'NR>1 {print $1":"$2}' | grep -q "$IMAGE_NAME"; then
  echo "⚠️ 동일 태그 이미지가 이미 존재하므로 기존 버전 이미지를 덮어씁니다: $IMAGE_NAME"
  nerdctl -n $NERDCTL_NS rmi -f "$IMAGE_NAME"
else
  echo "🆕 최초 빌드입니다: $IMAGE_NAME"
fi

echo "🚀 [빌드] nerdctl -n $NERDCTL_NS로 이미지 빌드 시작 → $IMAGE_NAME"
nerdctl -n $NERDCTL_NS build -t "$IMAGE_NAME" .

echo "✅ 빌드 완료: $IMAGE_NAME"

# 이미지 타임스탬프 최신화: save → rmi → load (동일 네임스페이스)
TMP_IMAGE_TAR="${APP_NAME}_${IMAGE_TAG}.tar"
echo "🕒 이미지 타임스탬프 최신화를 위해 save/load 수행..."
nerdctl -n $NERDCTL_NS save "$IMAGE_NAME" -o "$TMP_IMAGE_TAR"
nerdctl -n $NERDCTL_NS rmi "$IMAGE_NAME"
nerdctl -n $NERDCTL_NS load -i "$TMP_IMAGE_TAR"
rm -f "$TMP_IMAGE_TAR"

echo "📎 참고: 이 이미지는 imagePullPolicy: Never 설정 시 클러스터 내부에서 직접 사용됩니다."

# (선택) 최신 태그를 .env에 기록하고 싶다면 주석 해제
# sed -i '' "/^IMAGE_TAG=/d" ../.env
# echo "IMAGE_TAG=$IMAGE_TAG" >> ../.env
