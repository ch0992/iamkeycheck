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

echo "🧱 Colima(Kubernetes 포함) 클러스터를 시작합니다... (containerd 런타임 고정)"
colima stop || true
colima start --with-kubernetes --cpu 2 --memory 4 --disk 20 --runtime containerd

# nerdctl alias 설치 (Colima의 containerd에 로컬 nerdctl 프록시)
echo "🛠️ nerdctl alias(프록시) 설치 중..."
colima nerdctl install

# nerdctl info로 연결 확인
echo "🔍 nerdctl info로 Colima containerd 연결 상태 확인..."
nerdctl info || { echo '❌ nerdctl이 Colima containerd에 연결되지 않았습니다. Colima 상태와 nerdctl 설치를 확인하세요.'; exit 1; }

echo "🔗 kubectl context를 colima로 전환합니다..."
kubectl config use-context colima

echo "🔍 쿠버네티스 클러스터 노드 상태를 확인합니다..."
kubectl get nodes

echo "✅ nerdctl은 Mac에 별도 설치할 필요 없이, Colima가 프록시를 제공합니다."
echo "    nerdctl build -t your-image-name ."
echo "    nerdctl ps"
echo "    nerdctl images"
echo "  (모든 명령이 Colima VM의 containerd로 자동 전달됨)"
echo ""
echo "⚠️ 반드시 Colima가 실행 중이어야 nerdctl이 정상 동작합니다."
echo "⚠️ Colima가 docker 런타임이 아닌 containerd 런타임으로 실행되어야 합니다."
echo ""
echo "🎉 [완료] Colima 기반 Kubernetes + nerdctl 개발환경이 준비되었습니다."
