# 🌐 Terraform Infrastructure

이 디렉토리는 IAM Key Checker 애플리케이션의 인프라스트럭처를 정의하는 Terraform 코드를 포함합니다.

## 📁 디렉토리 구조

```
terraform/
├── environments/      # 환경별 설정
│   ├── dev/          # 개발 환경
│   │   ├── main.tf   # 주요 리소스 정의
│   │   ├── variables.tf # 환경 변수 정의
│   │   ├── provider.tf # Terraform 프로바이더 설정
│   │   └── env.auto.tfvars # 자동 생성된 환경 변수 파일
│   └── prod/         # 프로덕션 환경
│
└── modules/          # 재사용 가능한 모듈
    ├── app/         # 애플리케이션 모듈
    │   ├── deployment.tf # 애플리케이션 배포
    │   ├── service.tf    # 서비스 설정
    │   ├── secret.tf     # AWS 키 저장
    │   └── configmap.tf  # 환경 설정
    └── envoy/       # Envoy 프록시 모듈
        ├── deployment.tf # Envoy 프록시 배포
        ├── service.tf    # Ingress Gateway 설정
        └── configmap.tf  # Envoy 설정

## 📋 환경 변수

### 필수 환경 변수
```dotenv
# .env 파일에서 설정
STAGE=dev    # dev / prod
CSV_PATH=app/api/secrets/  # AWS 키 CSV 파일 경로
LOG_LEVEL=INFO  # 로그 레벨
```

### AWS 인증 정보
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

## 🏗️ 배포 과정

1. 환경 준비
```bash
# 1. Terraform 설치
brew install terraform
```

2. 배포 실행
```bash
# 1. Terraform 환경 준비
./scripts/4.prepare_terraform.sh

# 2. Terraform 배포
./scripts/5.deploy_terraform.sh
```

### 자동 설정
- 환경 변수 자동 로드 (.env)
- AWS 키 자동 추출 (CSV)
- 배포 승인 옵션 (-y 또는 --prompt)

## 🔄 자동화

### 3.deploy_all.sh
- 전체 배포 자동화
- AWS 키 자동 추출
- Terraform 배포 포함
- ConfigMap 업데이트
- Pod 상태 모니터링

## 🛠 모듈 설명

### app 모듈
- 애플리케이션 배포
- Kubernetes Deployment/Service
- ConfigMap 관리

### envoy 모듈
- Envoy 프록시 설정
- Ingress Gateway
- Service Discovery

## 📝 주의사항

1. **환경별 분리**
   - dev: 개발 환경
   - prod: 프로덕션 환경
   - 각 환경별 독립적인 리소스

2. **AWS 인증**
   - AWS 키는 CSV 파일에서 자동 추출
   - Kubernetes Secret에 저장 (iamkeycheck-aws-secret)
   - 환경 변수로도 설정 가능

3. **ConfigMap**
   - 환경별 설정 저장
   - 이미지 태그 관리
   - 환경 변수 전달
