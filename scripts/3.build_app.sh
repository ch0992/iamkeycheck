#!/bin/bash
set -e

# 1. 환경변수 초기화
unset STAGE
unset IMAGE_TAG


APP_NAME="iamkeycheck"
DEPLOYMENT_NAME="iamkeycheck-deployment"
DEFAULT_TAG="v1.0.0"
NERDCTL_NS="k8s.io"  # Colima K8s 네임스페이스

# 2. .env 파일에서 환경변수 불러오기
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "[DEBUG] .env 파일이 존재하지 않습니다."
fi

# 3. STAGE 기본값 설정
STAGE="${STAGE:-dev}"
echo "[DEBUG] 최종 STAGE=$STAGE"

# CSV 파일 검증 함수
csv_validation() {
  local csv_dir="$1"
  
  if [ ! -d "$csv_dir" ]; then
    echo "❌ $csv_dir 디렉토리가 없습니다."
    return 1
  fi

  local csv_files
  csv_files=$(find "$csv_dir" -type f -name "*.csv")
  if [ -z "$csv_files" ]; then
    echo "❌ $csv_dir에 CSV 파일이 없습니다."
    return 1
  fi

  echo "✅ $csv_dir에 다음 CSV 파일들이 있습니다:"
  echo "$csv_files"
  return 0
}

# 4. 현재 배포 태그 확인 (없으면 신규 배포로 판단)
CURRENT_TAG=$(kubectl get configmap iamkeycheck-config -n "$STAGE" -o jsonpath='{.data.IMAGE_TAG}' 2>/dev/null || echo "")

# 5. 배포이력이 없는 경우 CSV → AWS 키 추출 및 export
if [ -z "$CURRENT_TAG" ]; then
  if ! csv_validation "$CSV_PATH"; then
    exit 1
  fi

  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    if command -v python3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
      CREDS_JSON=$(PYTHONPATH=. python3 ./scripts/../app/util/extract_aws_creds.py | grep -E '^\{.*\}$')
      AWS_ACCESS_KEY_ID=$(echo "$CREDS_JSON" | jq -r .AWS_ACCESS_KEY_ID)
      AWS_SECRET_ACCESS_KEY=$(echo "$CREDS_JSON" | jq -r .AWS_SECRET_ACCESS_KEY)
      export AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY
      echo "🔑 CSV에서 AWS 키를 자동 추출하여 Terraform에 export 완료"
    else
      echo "❌ python3 또는 jq가 설치되어 있지 않습니다. 수동으로 AWS 키를 지정하세요."
      exit 1
    fi
  fi
fi

# 6. 다음 이미지 태그 계산 (기존 버전이 있다면 +1)
CURRENT_TAG=$(kubectl get configmap iamkeycheck-config -n "$STAGE" -o jsonpath='{.data.IMAGE_TAG}' 2>/dev/null || echo "")
if [[ "$CURRENT_TAG" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
  patch=$((patch + 1))
  IMAGE_TAG="v${major}.${minor}.${patch}"
else
  IMAGE_TAG="v1.0.0"
fi
IMAGE_NAME="${APP_NAME}:${STAGE}-${IMAGE_TAG}"

# 7. 테스트 실행
echo "🧪 Running pytest..."
pytest ./app/tests
if [ $? -ne 0 ]; then
  echo "❌ 테스트 실패. 빌드 중단"
  exit 1
fi

# 8. 기존 동일 태그 이미지가 있으면 제거 후 빌드
if nerdctl -n $NERDCTL_NS images | awk 'NR>1 {print $1":"$2}' | grep -q "$IMAGE_NAME"; then
  echo "⚠️ 동일 태그 이미지가 존재 → 삭제 후 재빌드: $IMAGE_NAME"
  nerdctl -n $NERDCTL_NS rmi -f "$IMAGE_NAME"
else
  echo "🆕 신규 빌드 시작: $IMAGE_NAME"
fi

# 9. 이미지 빌드
echo "🚀 nerdctl 빌드 시작 → $IMAGE_NAME"
nerdctl -n $NERDCTL_NS build -t "$IMAGE_NAME" .

# 10. 결과 확인
echo "✅ 빌드 완료: $IMAGE_NAME"
echo "[📦 iamkeycheck 이미지 목록]"
nerdctl -n $NERDCTL_NS images | awk -v image="$APP_NAME" -v stagetag="$STAGE-$IMAGE_TAG" '$1==image && $2==stagetag {print $0}' || echo "(이미지 없음)"

# 11. 참고 메시지
echo "📎 imagePullPolicy: Never 조건 하에서 이 이미지는 클러스터 내부에서 직접 사용됩니다."