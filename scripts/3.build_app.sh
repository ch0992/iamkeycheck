#!/bin/bash
set -e

# 1. 환경변수 초기화
unset STAGE
unset IMAGE_TAG
unset CSV_PATH
unset LOG_LEVEL
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY


APP_NAME="iamkeycheck"
DEPLOYMENT_NAME="iamkeycheck-deployment"
DEFAULT_TAG="v1.0.0"
NERDCTL_NS="k8s.io"  # Colima K8s 네임스페이스

# 2. .env 파일에서 환경변수 불러오기
env_file=".env"
if [ -f "$env_file" ]; then
  set -a
  source "$env_file"
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
  
  # 디렉토리 존재 여부 검사
  if [ ! -d "$csv_dir" ]; then
    echo "❌ $csv_dir 디렉토리가 없습니다."
    return 1
  fi

  # CSV 파일 검색
  local csv_files=$(find "$csv_dir" -type f -name "*.csv")
  if [ -z "$csv_files" ]; then
    echo "❌ $csv_dir에 CSV 파일이 없습니다."
    return 1
  fi

  # CSV 파일 정보 출력
  echo "✅ $csv_dir에 다음 CSV 파일들이 있습니다:"
  echo "$csv_files"
  
  return 0
}


# 배포이력 확인
CURRENT_TAG=$(kubectl get configmap iamkeycheck-config -n "$STAGE" -o jsonpath='{.data.IMAGE_TAG}' 2>/dev/null || echo "")

# 배포이력이 없는 경우에만 CSV 파일 검증과 AWS 키 추출 실행
if [ -z "$CURRENT_TAG" ]; then
  # CSV 파일 검증 실행
  if ! csv_validation "$CSV_PATH"; then
    exit 1
  fi

  # AWS 키 자동 추출
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    if command -v python3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
      CREDS_JSON=$(PYTHONPATH=. python3 ./scripts/../app/util/extract_aws_creds.py | grep -E '^\{.*\}$')
      AWS_ACCESS_KEY_ID=$(echo "$CREDS_JSON" | jq -r .AWS_ACCESS_KEY_ID)
      AWS_SECRET_ACCESS_KEY=$(echo "$CREDS_JSON" | jq -r .AWS_SECRET_ACCESS_KEY)
      export AWS_ACCESS_KEY_ID
      export AWS_SECRET_ACCESS_KEY
      echo "🔑 CSV에서 AWS 키를 자동 추출했습니다."
    else
      echo "❌ AWS 키가 없고, python3/jq가 설치되어 있지 않습니다. 수동으로 입력하거나 패키지를 설치하세요."
      exit 1
    fi
  fi
fi



# 4. configmap에서 IMAGE_TAG 조회 후 +1 증가(없으면 v1.0.0)
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

# 5. Pytest로 테스트 코드 실행 (실패 시 빌드 중단)
echo "🧪 Running pytest..."
pytest ./app/tests
if [ $? -ne 0 ]; then
  echo "❌ Pytest failed! Build aborted."
  exit 1
fi

# 6. 동일 태그 이미지가 있으면 삭제(덮어쓰기), 없으면 최초 빌드 안내
if nerdctl -n $NERDCTL_NS images | awk 'NR>1 {print $1":"$2}' | grep -q "$IMAGE_NAME"; then
  echo "⚠️ 동일 태그 이미지가 이미 존재하므로 기존 버전 이미지를 덮어씁니다: $IMAGE_NAME"
  nerdctl -n $NERDCTL_NS rmi -f "$IMAGE_NAME"
else
  echo "🆕 최초 빌드입니다: $IMAGE_NAME"
fi

# 7. Docker/nerdctl로 이미지 빌드
echo "🚀 [빌드] nerdctl -n $NERDCTL_NS로 이미지 빌드 시작 → $IMAGE_NAME"
nerdctl -n $NERDCTL_NS build -t "$IMAGE_NAME" .

echo "✅ 빌드 완료: $IMAGE_NAME"

# 8. 빌드된 이미지는 imagePullPolicy: Never로 클러스터 내부에서 직접 사용
echo "📎 참고: 이 이미지는 imagePullPolicy: Never 설정 시 클러스터 내부에서 직접 사용됩니다."

# 9. 빌드 후 iamkeycheck 이미지 목록 출력
echo "[최신 iamkeycheck 이미지 정보]"
nerdctl -n k8s.io images | awk -v image="$APP_NAME" -v stagetag="$STAGE-$IMAGE_TAG" '$1==image && $2==stagetag {print $0}' || echo "(iamkeycheck 이미지 없음)"

# 10. (선택) 최신 태그를 .env에 기록하려면 아래 주석 해제
# sed -i '' "/^IMAGE_TAG=/d" ../.env
# echo "IMAGE_TAG=$IMAGE_TAG" >> ../.env