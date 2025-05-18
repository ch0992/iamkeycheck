#!/bin/bash
set -e

# 1. 디버깅 옵션 활성화
set -x

# 2. .env 파일 로딩
env_file=".env"
if [ -f "$env_file" ]; then
  set -a
  source "$env_file"
  set +a
fi

# 3. 실행 옵션 파싱 (auto_approve 여부)
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
TF_BIN="${TF_BIN:-$HOME/.local/bin/terraform}"
APP_NAME="iamkeycheck"

# 5. 최신 iamkeycheck 이미지 태그 조회
IMAGE_TAG=$(nerdctl -n k8s.io images | awk -v stage="$STAGE" '$1=="iamkeycheck" && $2 ~ "^"stage"-v[0-9]+\\.[0-9]+\\.[0-9]+$" {gsub("^"stage"-", "", $2); print $2}' | sort -V | tail -n1)
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG=$(nerdctl -n k8s.io images | awk '$1=="iamkeycheck" && $2=="latest" {print $2}')
fi
if [ -z "$IMAGE_TAG" ]; then
  echo "❌ [배포 중단] 사용할 iamkeycheck 이미지가 없습니다."
  exit 2
fi
echo "[DEBUG] 배포에 사용할 IMAGE_TAG: $IMAGE_TAG"

DEPLOYMENT_NAME="${APP_NAME}-deployment-${STAGE}-${IMAGE_TAG}"
APP_LABEL="${APP_NAME}-${STAGE}-${IMAGE_TAG}"

# 6. configmap에서 현재 배포된 IMAGE_TAG 추출
CONFIGMAP_DEPLOYED_TAG=$(kubectl get configmap iamkeycheck-config -n "$STAGE" -o jsonpath='{.data.IMAGE_TAG}' 2>/dev/null || echo "")

# 7. env.auto.tfvars 파일의 image_tag 동기화
TFVARS_FILE="$WORK_DIR/env.auto.tfvars"
if [ -f "$TFVARS_FILE" ]; then
  if [ -z "$CONFIGMAP_DEPLOYED_TAG" ] || { [ "$(printf '%s\n%s\n' "$CONFIGMAP_DEPLOYED_TAG" "$IMAGE_TAG" | sort -V | tail -n1)" = "$IMAGE_TAG" ] && [ "$CONFIGMAP_DEPLOYED_TAG" != "$IMAGE_TAG" ]; }; then
    if grep -q '^image_tag' "$TFVARS_FILE"; then
      sed -i.bak "s/^image_tag *=.*/image_tag = \"$IMAGE_TAG\"/" "$TFVARS_FILE"
    else
      echo "image_tag = \"$IMAGE_TAG\"" >> "$TFVARS_FILE"
    fi
    echo "📄 env.auto.tfvars 동기화 완료 → image_tag=$IMAGE_TAG (기존 배포 태그: $CONFIGMAP_DEPLOYED_TAG)"
  else
    echo "configmap의 IMAGE_TAG($CONFIGMAP_DEPLOYED_TAG)보다 빌드된 태그($IMAGE_TAG)가 높지 않아 업데이트하지 않음"
  fi
fi

# 8. AWS 키 자동 추출
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

# 9. 네임스페이스 import (에러 무시)
$TF_BIN -chdir="$WORK_DIR" import 'module.app.kubernetes_namespace.this' "$STAGE" 2>/dev/null || true
$TF_BIN -chdir="$WORK_DIR" import 'module.envoy.kubernetes_namespace.this' "$STAGE" 2>/dev/null || true

cd "$WORK_DIR"

# 10. Terraform plan 실행
echo "📋 Terraform plan 실행..."
$TF_BIN plan -input=false \
  -var "aws_access_key_id=$AWS_ACCESS_KEY_ID" \
  -var "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY"

# 11. Terraform apply 함수 정의 (충돌/롤백 Robust 처리)
apply_with_retry() {
  set +e
  APPLY_LOG=$(mktemp)
  $TF_BIN apply -input=false -auto-approve \
    -var "aws_access_key_id=$AWS_ACCESS_KEY_ID" \
    -var "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY" 2>&1 | tee "$APPLY_LOG"
  STATUS=${PIPESTATUS[0]}
  set -e

  # NodePort 충돌 시 envoy-service 자동 삭제 후 1회 재시도
  if grep -q 'Service \"envoy-service\" is invalid: spec.ports\[0\].nodePort: Invalid value: [0-9]\+: provided port is already allocated' "$APPLY_LOG"; then
    echo "⚠️ NodePort 충돌 감지: 기존 envoy-service를 삭제 후 재시도합니다."
    kubectl delete service envoy-service -n "$STAGE" --ignore-not-found
    $TF_BIN apply -input=false -auto-approve \
      -var "aws_access_key_id=$AWS_ACCESS_KEY_ID" \
      -var "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY"
    STATUS=$?
    if [ $STATUS -eq 0 ]; then
      return 0
    else
      echo "❌ envoy-service 삭제 후에도 배포 실패! 로그를 확인하세요."
      cat "$APPLY_LOG"
      return $STATUS
    fi
  fi

  # 이미 존재하는 Deployment로 인한 apply 실패 시 롤백/삭제 처리
  if grep -q 'Failed to create deployment: deployments.apps.*already exists' "$APPLY_LOG"; then
    echo "⚠️ 이미 존재하는 Deployment로 인해 apply 실패!"
    set +e
    REV_COUNT=$(kubectl rollout history deployment/$DEPLOYMENT_NAME -n "$STAGE" 2>/dev/null | grep -c Revision)
    set -e
    if [ "$REV_COUNT" -eq 0 ]; then
      echo "🧹 배포 이력 없이 deployment만 존재 → 리소스 삭제 및 종료"
      kubectl delete deployment/$DEPLOYMENT_NAME -n "$STAGE" --ignore-not-found || true
      kubectl wait --for=delete deployment/$DEPLOYMENT_NAME -n "$STAGE" --timeout=30s || true
      kubectl delete pods -l app=$APP_LABEL -n "$STAGE" --ignore-not-found || true
      kubectl wait --for=delete pod -l app=$APP_LABEL -n "$STAGE" --timeout=30s || true
      kubectl delete replicaset -l app=$APP_LABEL -n "$STAGE" --ignore-not-found || true
      kubectl wait --for=delete replicaset -l app=$APP_LABEL -n "$STAGE" --timeout=30s || true
      kubectl delete configmap iamkeycheck-config -n "$STAGE" --ignore-not-found || true
      kubectl wait --for=delete configmap/iamkeycheck-config -n "$STAGE" --timeout=30s || true
      SERVICE_NAME=${SERVICE_NAME:-iamkeycheck-service-$STAGE}
      kubectl delete service $SERVICE_NAME -n "$STAGE" --ignore-not-found || true
      kubectl wait --for=delete service/$SERVICE_NAME -n "$STAGE" --timeout=30s || true
      echo "[INFO] 리소스 및 관련 리소스 삭제 후 프로세스 종료 (exit 1)"
      exit 1
    else
      echo "🔄 이전 성공 버전으로 롤백 시도..."
      kubectl rollout undo deployment/$DEPLOYMENT_NAME -n "$STAGE"
      sleep 3
      $TF_BIN apply -input=false -auto-approve \
        -var "aws_access_key_id=$AWS_ACCESS_KEY_ID" \
        -var "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY"
      return $?
    fi
  fi
  return $STATUS
}

# 12. 변경점 감지: plan 실행 (터미널에 항상 출력)
echo "🔍 Terraform 변경점(plan) 감지 중..."
$TF_BIN plan -input=false -detailed-exitcode \
  -var "aws_access_key_id=$AWS_ACCESS_KEY_ID" \
  -var "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY" | tee /tmp/tfplan.log
PLAN_EXIT_CODE=${PIPESTATUS[0]}

# 13. 변경점에 따라 배포/중단/실패 처리
if [ $PLAN_EXIT_CODE -eq 0 ]; then
  echo "✅ 변경점 없음: 리소스 배포를 건너뜁니다."
  exit 0
elif [ $PLAN_EXIT_CODE -eq 2 ]; then
  echo "🟡 변경점 있음: apply를 진행합니다."
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
else
  echo "❌ plan 실패! 로그를 확인하세요."
  cat /tmp/tfplan.log
  exit 1
fi
cd - > /dev/null

# 14. 배포 상태 확인 및 단계별 Robust 처리

# 14-1. Pod 상태 wait로 점검
POD_WAIT_TIMEOUT=30s
echo "⏳ [STEP] Pod Ready 상태 대기 중... (최대 $POD_WAIT_TIMEOUT)"
kubectl wait --for=condition=Ready pod -l app=$APP_LABEL -n "$STAGE" --timeout=$POD_WAIT_TIMEOUT
READY_RESULT=$?
if [ $READY_RESULT -ne 0 ]; then
  echo "❌ [ERROR] 일정 시간 내에 Pod가 Ready 상태가 되지 않았습니다."
  kubectl get pods -n "$STAGE" -l app=$APP_LABEL -o wide
  exit 1
else
  echo "✅ iamkeycheck 배포가 정상적으로 완료되었습니다!"
  echo "[현재 $STAGE 네임스페이스 iamkeycheck 관련 Pod 상태]"
  kubectl get pods -n "$STAGE" -l app=$APP_LABEL -o wide
fi

# 14-2. rollout status 체크 및 실패시 삭제
echo

# rollout status 체크
set +x  # 디버그 off (명령어 echo 방지)
printf "\033[1;36m⏳ [STEP] rollout status 체크...\033[0m\n"
kubectl rollout status deployment/$DEPLOYMENT_NAME -n "$STAGE" --timeout=20s

# Pod Ready 상태 체크 (중간 연산 노출 없이)
READY_COUNT=$(kubectl get pods -n "$STAGE" -l app=$APP_LABEL -o 'jsonpath={range .items[*]}{.metadata.name}={.status.containerStatuses[0].ready}{"\n"}{end}' | grep =true | wc -l 2>/dev/null | xargs)
TOTAL_COUNT=$(kubectl get pods -n "$STAGE" -l app=$APP_LABEL --no-headers | wc -l 2>/dev/null | xargs)
if [[ $READY_COUNT -eq $TOTAL_COUNT && $TOTAL_COUNT -gt 0 ]]; then
  printf "\033[1;32m✅ [SUCCESS] 모든 Pod가 Ready 상태입니다!\033[0m\n"
  # configmap(app_config) IMAGE_TAG 갱신
  kubectl -n "$STAGE" patch configmap iamkeycheck-config --type merge -p '{"data":{"IMAGE_TAG":"'$IMAGE_TAG'"}}' > /dev/null 2>&1
  printf "\033[1;34m📄 configmap(app_config) 업데이트 완료 → IMAGE_TAG=%s\033[0m\n" "$IMAGE_TAG"
  set -x  # 필요시 다시 디버그 on
  exit 0
else
  printf "\033[1;33m⚠️  [WARNING] Ready 상태가 아닌 Pod가 있습니다.\033[0m\n"
  # 문제가 있는 Pod의 로그 출력 (예시)
  for pod in $(kubectl get pods -n "$STAGE" -l app=$APP_LABEL --no-headers | awk '{print $1}'); do
    kubectl logs -n "$STAGE" $pod || true
  done
  exit 1
fi