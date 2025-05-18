# iamkeycheck

## 🔍 프로젝트 개요

`iamkeycheck`는 AWS IAM 사용자 Access Key 중 **N시간 이상 경과된 키를 필터링**하는 FastAPI 기반의 웹 애플리케이션입니다.  
Colima 기반 로컬 Kubernetes(k3s) 클러스터에 Terraform으로 배포되며, 모든 구성 요소는 스크립트로 자동화되어 있습니다.

## 🛠️ 개발 환경

- **OS**: macOS Sonoma 14.6.1
- **CPU**: Apple M1 Pro
- **RAM**: 16GB

### 주요 도구 버전
- **Python**: 3.10 이상
- **Terraform**: 1.2.6
- **Kubernetes**: 1.29.1 (k3s)
- **Docker**: 25.0.2
- **Colima**: 최신 안정 버전

## 🛠️ 필수 요구사항

- Homebrew가 설치되어 있어야 합니다.
- 모든 스크립트는 프로젝트 루트 디렉토리(`/Users/ygtoken/workspace/iamkeycheck`)에서 실행되어야 합니다.

---

## 🎯 주요 기능

- `/stale-keys?n=24` 형태의 API로 N시간 이상 사용된 Access Key 조회
- IAM 정보는 `.env` 파일 내 `CSV_PATH`에서 지정한 `.csv` 파일 경로를 통해 입력
- FastAPI 앱의 Docker 이미지 빌드 자동화 및 태그 자동 관리
- Terraform을 통한 Kubernetes 리소스(ConfigMap, Deployment, Envoy 등) 선언적 관리
- `.env`의 `STAGE` 값에 따라 Kubernetes 네임스페이스(dev, prod 등)가 분리되어 배포됨

---

## 🧱 시스템 구성 요약

| 범주             | 사용 기술         | 설명 |
|------------------|------------------|------|
| **Application**  | FastAPI          | Python 기반 비동기 REST API 프레임워크 |
|                  | Uvicorn          | FastAPI를 실행하는 경량 ASGI 서버 |
| **Infrastructure** | k3s              | 로컬 단일 노드 Kubernetes 경량 배포판 |
|                  | Colima           | macOS에서 containerd 기반 VM 제공 (k3s 포함) |
|                  | Envoy            | Standalone Ingress Controller 및 Proxy |
| **Infra 관리 도구** | Terraform        | Kubernetes 리소스를 선언적으로 정의하고 배포 |
|                  | nerdctl (Colima) | Docker 대체 CLI, 이미지 빌드 및 로컬 배포 |

---

## 📁 폴더 구조

```
.
├── app/                      # FastAPI 애플리케이션 및 API 라우터
│   ├── api/                  # API 라우팅 및 secrets 경로
│   └── services/             # 서비스 레이어 (비즈니스 로직)
├── core/                     # IAM Access Key 필터링 로직
├── scripts/                  # 클러스터 관리, 빌드, 배포 자동화 스크립트
├── terraform/                # 환경별(Kubernetes) 리소스 선언 코드
│   └── environments/         # dev / prod 등 환경별 tfvars 분리
├── tests/                    # pytest 기반 테스트 코드
├── .env                      # 환경 변수 정의 파일
└── README.md                 # 프로젝트 전체 문서
```

---

## 📘 하위 문서 안내

각 주요 디렉토리에는 별도의 문서가 존재하며, 상세한 구현 및 설정 방법은 아래 문서를 참조하세요:

| 디렉토리   | 문서 위치             | 내용 요약 |
|------------|------------------------|-----------|
| `app/`     | [app/README.md](app/README.md)        | FastAPI 애플리케이션 구조, API 설명 및 주요 모듈 안내 |
| `scripts/` | [scripts/README.md](scripts/README.md)    | 실행 스크립트별 역할, 실행 순서, 주요 옵션 안내 |
| `terraform/` | [terraform/README.md](terraform/README.md) | 환경별 리소스 정의 구조, Terraform 모듈 설명 및 배포 전략 |

---

## 🗂 환경 분리 전략

- `.env` 파일의 `STAGE` 값을 기준으로 Kubernetes 네임스페이스가 동적으로 설정됩니다.
- Terraform은 `terraform/environments/{STAGE}` 디렉토리를 참조하며,  
  동일한 리소스 구조를 `dev`, `prod` 등으로 명확히 분리하여 관리합니다.

예시:

```dotenv
STAGE=dev
```

→ 해당 값은 `dev` 네임스페이스에 리소스를 배포하며, ConfigMap, Deployment, Service, Envoy 등이 분리되어 관리됩니다.

---

## ⚙️ 실행 방법

```bash
# 1. Python 패키지 설치
pip install -r requirements.txt

# 2. 로컬 Kubernetes 클러스터 실행
./scripts/1.start_cluster.sh

# 2.1 Terraform 설치 및 환경 설정 (stage 변경시 반드시 실행해야 terraform init이 실행되어 배포가능한 상태가 됨)
 * 각 스테이지 별로 한번씩 반드시 실행해야 함. 이후에는 3번, 4번으로 빌드 및 배포만 하면 됨
./scripts/2.prepare_terraform.sh

# 3. FastAPI 앱 이미지 빌드
./scripts/3.build_app.sh

# 4. FastAPI 앱 이미지 배포
./scripts/4.deploy_all.sh

# 5. 클러스터 종료
./scripts/5.destroy_cluster.sh
```

> **주의**: 모든 스크립트는 프로젝트 루트 디렉토리(`/Users/ygtoken/workspace/iamkeycheck`)에서 실행되어야 합니다.

> 각 스크립트의 세부 기능 및 옵션은 `scripts/README.md`를 참고하세요.

---

## IAM Access Key 설정 방법

> **⚠️ 반드시 `.csv` 파일을 제공해야 하며, `.env`를 통한 AWS 키 설정은 동작하지 않습니다.**

이 프로젝트는 AWS IAM 사용자 Access Key와 Secret을 기반으로 키 사용 상태를 분석합니다.  
`.csv` 파일만을 통해 IAM 정보를 입력받으며, `.env`의 `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` 값은 무시됩니다.

---

### ✅ 필수: `.csv` 파일로 제공

- `.env`에서 `CSV_PATH`를 지정합니다:

```dotenv
CSV_PATH=/app/secrets/applicant_accessKeys.csv
```

- `.csv` 파일은 반드시 다음과 같은 형식으로 작성되어야 합니다:

```csv
Access key ID,Secret access key
{Access key ID},{Secret access key}
```

- 위치: `app/api/secrets/`에 위치시키고 `CSV_PATH`에서 해당 경로를 지정하세요.