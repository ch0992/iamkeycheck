#!/bin/bash
set -e

# ===========================
# Colima + k3s 쿠버네티스 클러스터 시작 스크립트
# ===========================

# 0. Colima 설치 여부 확인 및 자동 설치
if ! which colima >/dev/null 2>&1; then
    echo "⚠️  colima가 설치되어 있지 않습니다. 설치하시겠습니까? (y/N) "
    read -r yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        echo "brew install colima 명령으로 자동 설치를 시작합니다."
        brew install colima
        if ! which colima >/dev/null 2>&1; then
            echo "❌ colima 설치에 실패했습니다. 수동으로 설치 후 다시 실행하세요."
            exit 1
        fi
        echo "✅ colima 설치 완료."
    else
        echo "colima가 설치되어 있지 않아 스크립트를 종료합니다."
        exit 1
    fi
else
    echo "✅ colima가 이미 설치되어 있습니다."
fi

echo "🧱 Colima(Kubernetes 포함) 클러스터를 시작합니다..."
colima start --with-kubernetes --cpu 2 --memory 4 --disk 20

echo "🔗 kubectl context를 colima로 전환합니다..."
kubectl config use-context colima

echo "🔍 쿠버네티스 클러스터 노드 상태를 확인합니다..."
kubectl get nodes

echo "🛠️ nerdctl은 Mac에서 직접 설치하지 않습니다."
echo "✅ 대신 Colima 내부에 포함되어 있으므로 다음처럼 사용하세요:"
echo ""
echo "    colima nerdctl build -t your-image-name ."
echo "    colima nerdctl ps"
echo ""
echo "⚠️ Colima가 실행 중이어야 nerdctl이 정상 동작합니다."

echo "🎉 [완료] Colima 기반 Kubernetes 클러스터가 준비되었습니다."
