#!/bin/bash
set -e

# 디버깅 옵션
set -x

# .env 파일 로딩
env_file=".env"
if [ -f "$env_file" ]; then
  set -a
  source "$env_file"
  set +a
fi

# 실행 옵션 파싱
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
TF_BIN="${TF_BIN:-$HOME/.local/bin/terraform}"
APP_NAME="iamkeycheck"
DEPLOYMENT_NAME="${APP_NAME}-deployment"

# IMAGE_TAG 자동 추출 (최초 또는 .env에 없을 때)
if [ -z "$IMAGE_TAG" ]; then
  # nerdctl images에서 iamkeycheck의 최신 태그 추출 (v* 우선, 없으면 latest)
  IMAGE_TAG=$(nerdctl images | awk '$1=="iamkeycheck" && $2 ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ {print $2}' | sort -V | tail -n1)
  if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG=$(nerdctl images | awk '$1=="iamkeycheck" && $2=="latest" {print $2}')
  fi
  if [ -z "$IMAGE_TAG" ]; then
    echo "❌ [배포 중단] 사용할 iamkeycheck 이미지가 없습니다.\n- nerdctl images에 iamkeycheck로 시작하는 태그(v*, latest 등)가 존재하지 않습니다.\n- 먼저 이미지를 빌드한 뒤 다시 배포를 시도하세요."
    exit 2
  else
    echo "ℹ️ .env에 IMAGE_TAG가 없어 nerdctl images에서 자동 추출: $IMAGE_TAG"
  fi
fi

# env.auto.tfvars의 image_tag 값을 최신 IMAGE_TAG로 동기화
TFVARS_FILE="$WORK_DIR/env.auto.tfvars"
if [ -f "$TFVARS_FILE" ]; then
  # image_tag 라인 있으면 교체, 없으면 추가
  if grep -q '^image_tag' "$TFVARS_FILE"; then
    sed -i.bak "s/^image_tag *=.*/image_tag = \"$IMAGE_TAG\"/" "$TFVARS_FILE"
  else
    echo "image_tag = \"$IMAGE_TAG\"" >> "$TFVARS_FILE"
  fi
  echo "📄 env.auto.tfvars 동기화 완료 → image_tag=$IMAGE_TAG"
fi

# AWS 키 자동 추출: .env/tfvars에 없으면 extract_aws_creds.py 사용
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

# 네임스페이스 import (에러 무시)
$TF_BIN -chdir="$WORK_DIR" import 'module.app.kubernetes_namespace.this' "$STAGE" 2>/dev/null || true
$TF_BIN -chdir="$WORK_DIR" import 'module.envoy.kubernetes_namespace.this' "$STAGE" 2>/dev/null || true

cd "$WORK_DIR"

# Terraform plan
echo "📋 Terraform plan 실행..."
$TF_BIN plan -input=false \
  -var "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
  -var "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"

# Terraform apply
apply_with_retry() {
  set +e
  APPLY_LOG=$(mktemp)
  $TF_BIN apply -input=false -auto-approve \
    -var "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
    -var "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" 2>&1 | tee "$APPLY_LOG"
  STATUS=${PIPESTATUS[0]}
  set -e
  if grep -q 'Failed to create deployment: deployments.apps.*already exists' "$APPLY_LOG"; then
    echo "⚠️ 이미 존재하는 Deployment로 인해 apply 실패!"
    set +e
    REV_COUNT=$(kubectl rollout history deployment/$DEPLOYMENT_NAME -n "$STAGE" 2>/dev/null | grep -c Revision)
    set -e
    if [ "$REV_COUNT" -eq 0 ]; then
      echo "🧹 배포 이력 없이 deployment만 존재 → 리소스 삭제 및 종료"
      kubectl delete deployment/$DEPLOYMENT_NAME -n "$STAGE" --ignore-not-found || true
      kubectl delete pods -l app=$APP_NAME -n "$STAGE" --ignore-not-found || true
      kubectl delete replicaset -l app=$APP_NAME -n "$STAGE" --ignore-not-found || true
      kubectl delete configmap iamkeycheck-config -n "$STAGE" --ignore-not-found || true
      kubectl delete service $SERVICE_NAME -n "$STAGE" --ignore-not-found || true
      echo "[INFO] 리소스 및 관련 리소스 삭제 후 프로세스 종료 (exit 1)"
      exit 1
    else
      echo "🔄 이전 성공 버전으로 롤백 시도..."
      kubectl rollout undo deployment/$DEPLOYMENT_NAME -n "$STAGE"
      sleep 3
      $TF_BIN apply -input=false -auto-approve \
        -var "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
        -var "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
      return $?
    fi
  fi
  return $STATUS
}


if [ "$auto_approve" = true ]; then
  echo "🚀 자동 승인 감지 → apply 바로 실행"
  apply_with_retry
else
  read -r -p "실제로 리소스를 생성하려면 'yes'를 입력하세요: " answer
  if [ "$answer" = "yes" ]; then
    apply_with_retry
  else
    echo "⏹️ 리소스 생성 취소됨"
    exit 0
  fi
fi
cd - > /dev/null

# 배포 상태 확인 및 단계별 Robust 처리

# 1. Pod 오류 즉시 감지 및 삭제
echo "⏳ [STEP] Pod 상태 즉시 점검..."
POD_ERROR=$(kubectl get pods -n "$STAGE" -l app=$APP_NAME \
  -o jsonpath='{range .items[*]}{.status.phase} {"|"}{.status.containerStatuses[0].state.waiting.reason} {"|"}{.status.containerStatuses[0].lastState.terminated.reason} {"|"}{.status.containerStatuses[0].state.terminated.reason}{"\n"}{end}' \
  | grep -E 'CrashLoopBackOff|Error|Failed|Unknown')
if [ -n "$POD_ERROR" ]; then
  echo "❌ [FAIL] Pod 오류 상태(CrashLoopBackOff/Error/Failed/Unknown) 감지 → 리소스 삭제 및 종료"
  kubectl delete deployment/$DEPLOYMENT_NAME -n "$STAGE" --ignore-not-found
  kubectl delete pods -l app=$APP_NAME -n "$STAGE" --ignore-not-found
  kubectl delete replicaset -l app=$APP_NAME -n "$STAGE" --ignore-not-found
  kubectl delete configmap iamkeycheck-config -n "$STAGE" --ignore-not-found
  kubectl delete service $SERVICE_NAME -n "$STAGE" --ignore-not-found
  echo "[INFO] Pod 오류로 리소스 삭제 후 종료 (exit 1)"
  exit 1
fi

# 2. rollout status 체크 및 실패시 삭제
echo "⏳ [STEP] rollout status 체크..."
if ! kubectl rollout status deployment/$DEPLOYMENT_NAME -n "$STAGE" --timeout=20s; then
  echo "❌ [FAIL] rollout 실패 → 리소스 삭제 및 종료"
  kubectl delete deployment/$DEPLOYMENT_NAME -n "$STAGE" --ignore-not-found
  kubectl delete pods -l app=$APP_NAME -n "$STAGE" --ignore-not-found
  kubectl delete replicaset -l app=$APP_NAME -n "$STAGE" --ignore-not-found
  kubectl delete configmap iamkeycheck-config -n "$STAGE" --ignore-not-found
  kubectl delete service $SERVICE_NAME -n "$STAGE" --ignore-not-found
  echo "[INFO] rollout 실패로 리소스 삭제 후 종료 (exit 1)"
  exit 1
fi

# 3. readinessProbe 체크 및 실패시 상태/로그 출력
READY_COUNT=$(kubectl get pods -n "$STAGE" \
  -l app=$APP_NAME \
  -o jsonpath='{range .items[*]}{.metadata.name}={.status.containerStatuses[0].ready}{"\n"}{end}' | grep "=true" | wc -l)
TOTAL_COUNT=$(kubectl get pods -n "$STAGE" -l app=$APP_NAME --no-headers | wc -l)
if [[ "$READY_COUNT" -eq "$TOTAL_COUNT" && "$TOTAL_COUNT" -gt 0 ]]; then
  echo "✅ [SUCCESS] 모든 Pod가 Ready 상태입니다 → configmap(app_config)의 IMAGE_TAG 갱신"
  kubectl -n "$STAGE" patch configmap iamkeycheck-config --type merge -p '{"data":{"IMAGE_TAG":"'$IMAGE_TAG'"}}'
  echo "📄 configmap(app_config) 업데이트 완료 → IMAGE_TAG=$IMAGE_TAG"
  exit 0
else
  echo "⚠️ [FAIL] 일부 Pod가 Ready 상태가 아닙니다 ($READY_COUNT/$TOTAL_COUNT)"
  kubectl get pods -n "$STAGE" -l app=$APP_NAME -o wide
  for pod in $(kubectl get pods -n "$STAGE" -l app=$APP_NAME -o jsonpath='{.items[*].metadata.name}'); do
    echo "------ $pod logs ------"
    kubectl logs -n "$STAGE" $pod || true
  done
  exit 1
fi
