#!/bin/bash
set -e
set -x

# 삭제할 리소스 목록 (필요시 추가)
DEPLOYMENTS=(iamkeycheck-deployment envoy-deployment)
CONFIGMAPS=(iamkeycheck-config envoy-config)
SERVICES=(envoy-service)

# .env에서 STAGE(네임스페이스) 자동 감지
if [ -z "$NAMESPACE" ] && [ -z "$1" ]; then
  if [ -f .env ]; then
    STAGE=$(grep '^STAGE=' .env | cut -d'=' -f2 | tr -d '"')
    NAMESPACE=${STAGE:-default}
  else
    NAMESPACE=default
  fi
else
  NAMESPACE="${NAMESPACE:-${1:-default}}"
fi

echo "[INFO] 대상 네임스페이스: $NAMESPACE"

for d in "${DEPLOYMENTS[@]}"; do
  kubectl delete deployment "$d" -n "$NAMESPACE" --ignore-not-found
done
for c in "${CONFIGMAPS[@]}"; do
  kubectl delete configmap "$c" -n "$NAMESPACE" --ignore-not-found
done
for s in "${SERVICES[@]}"; do
  kubectl delete service "$s" -n "$NAMESPACE" --ignore-not-found
done

echo "✅ Kubernetes 리소스 삭제 완료!"

# 네임스페이스 자체 삭제
if [ "$NAMESPACE" != "default" ]; then
  kubectl delete namespace "$NAMESPACE" --ignore-not-found
  echo "🧹 네임스페이스 '$NAMESPACE' 삭제 완료!"
else
  echo "⚠️  'default' 네임스페이스는 삭제하지 않습니다."
fi
