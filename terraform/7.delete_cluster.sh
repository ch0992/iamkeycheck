#!/bin/bash
set -e
set -x

# Colima 기반 쿠버네티스 클러스터 정지 및 삭제 스크립트

# 1. Colima 클러스터 정지 및 삭제
if command -v colima >/dev/null 2>&1; then
  echo "[INFO] Colima 클러스터 정지 및 삭제 시도..."
  colima stop default || true
  colima delete default || true
  echo "[INFO] Colima 클러스터가 정지 및 삭제되었습니다."
else
  echo "[WARN] colima 명령이 없습니다. Colima가 설치되어 있는지 확인하세요."
fi

# 2. docker desktop (kubernetes) 환경은 별도 삭제 없음. (참고 메시지)

# 3. nerdctl/ctr 기반 리소스 정리 (필요시)
# echo "[INFO] nerdctl/ctr 기반 리소스 정리(선택)"
# nerdctl system prune -a -f

# 4. kubeconfig 정리 (선택)
# echo "[INFO] kubeconfig 파일 정리(선택)"
# rm -f ~/.kube/config

# 완료 메시지
echo "✅ 로컬 Colima 쿠버네티스 클러스터 정지 및 삭제 스크립트가 완료되었습니다."