#!/bin/bash
# kubectl 또는 terraform 배포 자동화

echo "[K8S] 배포 중..."
# kubectl apply -f k8s/

echo "[TF] Terraform 배포 중..."
# terraform -chdir=terraform/environments/dev init
# terraform -chdir=terraform/environments/dev apply -auto-approve
