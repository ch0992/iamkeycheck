#!/bin/bash
set -e
set -x

# 1. .env 파일 로딩: 환경변수 자동 적용
env_file=".env"
if [ -f "$env_file" ]; then
  set -a
  source "$env_file"
  set +a
fi

# 2. AWS 키 자동 추출: .env/tfvars에 없으면 extract_aws_creds.py 사용
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  if command -v python3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    CREDS_JSON=$(PYTHONPATH=. python3 ./scripts/../app/util/extract_aws_creds.py | grep -E '^{.*}$')
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

# 3. 배포 승인 옵션 파싱
# Usage: ./deploy_terraform.sh [-y] [--prompt]
# -y: 자동 승인 (auto_approve=true)
# --prompt: 수동 승인 (auto_approve=false)
# 기본값: -y가 없으면 자동 승인
auto_approve=true
for arg in "$@"; do
  if [[ "$arg" == "--prompt" ]]; then
    auto_approve=false
  fi
  if [[ "$arg" == "-y" ]]; then
    auto_approve=true
  fi
done

# 4. 주요 변수 설정
STAGE=${STAGE:-dev}
WORK_DIR="terraform/environments/$STAGE"
TF_BIN="$HOME/.local/bin/terraform"

# 5. 이미 존재하는 네임스페이스를 import (에러 무시)
$TF_BIN -chdir="$WORK_DIR" import 'module.app.kubernetes_namespace.this' "$STAGE" 2>/dev/null || true
$TF_BIN -chdir="$WORK_DIR" import 'module.envoy.kubernetes_namespace.this' "$STAGE" 2>/dev/null || true

cd "$WORK_DIR"

# 6. Terraform plan 실행
echo "📋 Terraform plan 실행..."
$TF_BIN plan -input=false \
  -var "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
  -var "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"

# 7. Terraform apply (자동/수동 분기)
if [ "$auto_approve" = true ]; then
  echo "[자동배포] -y 옵션이 감지되어 오류 없으면 바로 apply 진행합니다."
  # apply_with_retry 함수 정의 (여기서는 단순 적용)
  apply_with_retry() {
    set +e
    APPLY_LOG=$(mktemp)
    $TF_BIN apply -input=false -auto-approve \
      -var "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
      -var "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
      2>&1 | tee "$APPLY_LOG"
    STATUS=${PIPESTATUS[0]}
    set -e
  }
  apply_with_retry
else
  # 사용자 승인 후 apply만 프롬프트 실행
  read -r -p "실제로 리소스를 생성하려면 'yes'를 입력하세요. (terraform apply): " answer
  if [ "$answer" = "yes" ]; then
    "$TF_BIN" apply -input=false \
      -var "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
      -var "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
  else
    echo "⏹️  리소스 생성이 취소되었습니다."
  fi
fi
cd - > /dev/null