#!/bin/bash
set -e
set -x

echo "[준비] Terraform 설치 확인 및 환경 준비"

# 1. 환경 변수 로딩 및 env.auto.tfvars 생성
ENV_FILE=.env
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env 파일이 없습니다."
  exit 1
fi
set -a
source .env
set +a

# 2. 필수 환경변수(STAGE) 확인
if [ -z "$STAGE" ]; then
  echo "❌ STAGE 환경변수가 필요합니다."
  exit 1
fi
WORK_DIR="terraform/environments/$STAGE"
echo "✅ STAGE=$STAGE → 작업 디렉토리: $WORK_DIR"

# 3. env.auto.tfvars 파일 생성 (주요 변수만 기록)
echo "STAGE = \"$STAGE\"" > "$WORK_DIR/env.auto.tfvars"
echo "namespace = \"$STAGE\"" >> "$WORK_DIR/env.auto.tfvars"
[ -n "$CSV_PATH" ] && echo "CSV_PATH = \"$CSV_PATH\"" >> "$WORK_DIR/env.auto.tfvars"
[ -n "$LOG_LEVEL" ] && echo "LOG_LEVEL = \"$LOG_LEVEL\"" >> "$WORK_DIR/env.auto.tfvars"
: "${image_tag:=${IMAGE_TAG:-latest}}"
: "${n_hours:=${N_HOURS:-24}}"
echo "image_tag = \"$image_tag\"" >> "$WORK_DIR/env.auto.tfvars"
echo "n_hours = $n_hours" >> "$WORK_DIR/env.auto.tfvars"
echo "✅ $WORK_DIR/env.auto.tfvars 생성 완료 (AWS 변수는 무시됨)"

# 4. Terraform 바이너리 확인 및 자동 설치
TERRAFORM_VERSION=1.2.6
TF_BIN="$HOME/.local/bin/terraform"
export PATH="$HOME/.local/bin:$PATH"
if [ ! -x "$TF_BIN" ]; then
  echo "⚠️  terraform 바이너리가 없어 직접 다운로드 시도"
  mkdir -p "$HOME/.local/bin"
  curl -Lo "$TF_BIN.zip" "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_darwin_amd64.zip"
  unzip -o "$TF_BIN.zip" -d "$HOME/.local/bin"
  rm "$TF_BIN.zip"
  chmod +x "$TF_BIN"
fi

# 5. Terraform 프로젝트 초기화 및 검증
cd "$WORK_DIR"
"$TF_BIN" init -input=false     # 플러그인 다운로드 및 초기화
"$TF_BIN" fmt -check           # 코드 스타일 검사
"$TF_BIN" validate             # 구문 및 구성 유효성 검사
cd - > /dev/null

echo "✅ Terraform 준비 완료!"