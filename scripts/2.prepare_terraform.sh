#!/bin/bash
set -e
set -x

# 1. .env 파일에서 STAGE 및 기타 환경 변수 로딩
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "❌ .env 파일이 없습니다."
  exit 1
fi

# 2. STAGE가 비어 있으면 기본값은 dev
STAGE="${STAGE:-dev}"

# 3. 작업 디렉토리 및 Terraform 실행 바이너리 설정
WORK_DIR="terraform/environments/$STAGE"
TF_BIN="${TF_BIN:-$HOME/.local/bin/terraform}"

# 3-1. Terraform 자동 설치 (없을 경우)
if [ ! -x "$TF_BIN" ]; then
  echo "📦 terraform 실행파일이 없어 설치를 시작합니다..."
  TERRAFORM_VERSION="1.2.6"
  mkdir -p "$(dirname "$TF_BIN")"
  curl -Lo "$TF_BIN.zip" "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_darwin_arm64.zip"
  unzip -o "$TF_BIN.zip" -d "$(dirname "$TF_BIN")"
  rm "$TF_BIN.zip"
  chmod +x "$TF_BIN"
  echo "✅ terraform 설치 완료 → $TF_BIN"
fi

echo "🔧 [$STAGE] 작업 디렉토리: $WORK_DIR"
cd "$WORK_DIR"

# 4. 이전 초기화 캐시 제거 및 terraform init
[ -d ".terraform" ] && rm -rf .terraform
if ! "$TF_BIN" init -input=false -upgrade=true -reconfigure; then
  echo "❌ [$STAGE] terraform init 실패"
  exit 1
fi

# 5. 코드 포맷 확인 및 유효성 검사
"$TF_BIN" fmt -check
"$TF_BIN" validate

# 6. env.auto.tfvars 파일 생성
echo "stage = \"$STAGE\"" > env.auto.tfvars
echo "namespace = \"$STAGE\"" >> env.auto.tfvars
[ -n "$CSV_PATH" ] && echo "csv_path = \"$CSV_PATH\"" >> env.auto.tfvars
[ -n "$LOG_LEVEL" ] && echo "log_level = \"$LOG_LEVEL\"" >> env.auto.tfvars
: "${image_tag:=${IMAGE_TAG}}"
: "${n_hours:=${N_HOURS:-24}}"
echo "image_tag = \"$image_tag\"" >> env.auto.tfvars
echo "n_hours = $n_hours" >> env.auto.tfvars

# 7. 완료 메시지 출력 후 이전 디렉토리 복귀
echo "✅ [$STAGE] 초기화 완료"
cd - > /dev/null