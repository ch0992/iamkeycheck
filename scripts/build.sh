#!/bin/bash
# Docker 빌드 + K8s ConfigMap/Secret 생성

echo "[BUILD] Docker 이미지 빌드 중..."
docker build -t iamkeycheck:latest .

echo "[K8S] ConfigMap/Secret 생성 예시 (kubectl 필요)"
# kubectl create configmap iamkeycheck-config --from-env-file=.env --dry-run=client -o yaml > k8s/configmap.yaml
# kubectl create secret generic iamkeycheck-secret --from-file=applicant_accessKeys.csv --dry-run=client -o yaml > k8s/secret.yaml
