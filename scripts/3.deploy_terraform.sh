#!/bin/bash
set -e
set -x

# .env 파일 자동 로드
env_file=".env"
if [ -f "$env_file" ]; then
  set -a
  source "$env_file"
  set +a
fi

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

STAGE=${STAGE:-dev}
WORK_DIR="terraform/environments/$STAGE"
TF_BIN="$HOME/.local/bin/terraform"

# 이미 존재하는 네임스페이스를 import (에러 무시)
$TF_BIN -chdir="$WORK_DIR" import 'module.app.kubernetes_namespace.this' "$STAGE" 2>/dev/null || true
$TF_BIN -chdir="$WORK_DIR" import 'module.envoy.kubernetes_namespace.this' "$STAGE" 2>/dev/null || true

cd "$WORK_DIR"

# Terraform plan
"$TF_BIN" plan -input=false

if [ "$auto_approve" = true ]; then
  echo "[자동배포] -y 옵션이 감지되어 오류 없으면 바로 apply 진행합니다."
  "$TF_BIN" apply -input=false -auto-approve
else
  # 사용자 승인 후 apply만 프롬프트 실행
  read -r -p "실제로 리소스를 생성하려면 'yes'를 입력하세요. (terraform apply): " answer
  if [ "$answer" = "yes" ]; then
    "$TF_BIN" apply -input=false
  else
    echo "⏹️  리소스 생성이 취소되었습니다."
  fi
fi
cd - > /dev/null
