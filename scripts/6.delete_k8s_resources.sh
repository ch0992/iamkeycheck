#!/bin/bash
set -e
set -x

# 1. 삭제할 리소스 목록 정의 (필요시 추가 가능)
DEPLOYMENTS=(iamkeycheck-deployment envoy-deployment)
CONFIGMAPS=(iamkeycheck-config envoy-config)
SERVICES=(envoy-service)

# 2. 모든 네임스페이스에서 iamkeycheck/관련 리소스 삭제 및 iamkeycheck 이미지 전체 삭제

# default 네임스페이스는 건드리지 않음
ALL_NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

for NAMESPACE in $ALL_NAMESPACES; do
  if [ "$NAMESPACE" = "default" ]; then
    echo "[INFO] 'default' 네임스페이스는 건너뜁니다."
    continue
  fi
  echo "[INFO] 네임스페이스 '$NAMESPACE' 리소스 삭제 시작"

  # 2-1. Deployment 삭제
  for d in "${DEPLOYMENTS[@]}"; do
    kubectl delete deployment "$d" -n "$NAMESPACE" --ignore-not-found
  done

  # 2-2. ConfigMap 삭제
  for c in "${CONFIGMAPS[@]}"; do
    kubectl delete configmap "$c" -n "$NAMESPACE" --ignore-not-found
  done

  # 2-3. Service 삭제
  for s in "${SERVICES[@]}"; do
    kubectl delete service "$s" -n "$NAMESPACE" --ignore-not-found
  done

  # 2-4. iamkeycheck 관련 Pod 종료 대기 (최대 60초)
  echo "[INFO] iamkeycheck 관련 Pod 종료 대기..."
  timeout=0
  while kubectl get pods -n "$NAMESPACE" | grep -q iamkeycheck; do
    echo "[INFO] Pod 종료 대기 중... ($NAMESPACE)"
    sleep 2
    timeout=$((timeout+2))
    if [ $timeout -ge 60 ]; then
      echo "[WARN] 60초가 경과했으나 일부 Pod가 남아있을 수 있습니다. 강제 진행합니다."
      break
    fi
  done

  # 2-5. 네임스페이스 자체 삭제
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
  echo "🧹 네임스페이스 '$NAMESPACE' 삭제 완료!"
done

echo "[INFO] 모든 네임스페이스 리소스 삭제 완료, iamkeycheck 이미지 전체 삭제 시작"

# 3. iamkeycheck 관련 nerdctl 이미지 전체 삭제
for tag in $(nerdctl -n k8s.io images | awk '$1=="iamkeycheck" {print $2}'); do
  echo "[INFO] iamkeycheck:$tag 이미지 삭제 시도"
  nerdctl -n k8s.io rmi iamkeycheck:$tag || true
  echo "[INFO] iamkeycheck:$tag 이미지 삭제 완료"
done

echo "✅ 모든 네임스페이스 리소스 및 iamkeycheck 이미지 전체 삭제 완료!"