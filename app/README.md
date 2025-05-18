# app 디렉토리 문서화

## 📋 개요

`app` 디렉토리는 FastAPI 기반의 웹 애플리케이션을 구성하는 핵심 코드가 위치한 디렉토리입니다. 
이 애플리케이션은 Uvicorn 서버를 기반으로 비동기 처리를 지원하며, 
AWS IAM Access Key의 사용 상태를 분석하는 기능을 제공합니다.

## 폴더/파일 구조

```
app/
├── api/                    # API 라우팅 정의
│   ├── routes/            # API 엔드포인트 라우팅
│   └── secrets/           # AWS IAM Access Key CSV 파일 저장 위치
├── core/                  # IAM 키 분석 핵심 로직
├── log/                   # 로그 설정 및 관리
├── services/              # 도메인 로직 및 인터페이스 구현
│   └── iamkeycheck/       # AWS IAM 키 분석 서비스
├── tests/                 # 테스트 코드
│   ├── test_api_stale_keys.py     # API 테스트
│   ├── test_csv_parsing.py        # CSV 파싱 테스트
│   └── test_key_filtering.py      # 키 필터링 테스트
└── util/                  # 유틸리티 모듈
    └── extract_aws_creds.py       # AWS 키 자동 추출
```

### 주요 폴더 설명

1. **api/**
   - API 라우팅 정의 및 인증 처리
   - `/stale-keys` 엔드포인트 구현
   - IAM 키 정보 CSV 파일 관리

2. **services/**
   - 도메인 로직 구현
   - AWS SDK 인터페이스 구현
   - 키 분석 서비스 구현

3. **secrets/**
   - AWS IAM Access Key CSV 파일 저장 위치
   - 권장 경로: `app/api/secrets/`
   - CSV 파일 형식:
     ```csv
     Access key ID,Secret access key
     {Access key ID},{Secret access key}
     ```

## 🔄 모듈 흐름

1. **API 요청 흐름**
   1. 클라이언트가 `/stale-keys?n=24` 요청
   2. FastAPI 라우터가 요청 처리
   3. 서비스 레이어에서 IAM 키 분석
   4. AWS SDK를 통한 키 상태 확인
   5. 결과 응답 반환

2. **에러 처리 흐름**
   - 모든 에러는 HTTPException으로 변환
   - 상세 에러 로깅
   - 클라이언트 친화적 에러 메시지

## 📚 API 예시

### 1. `/stale-keys?n=24`

- **기능**: N시간 이상 경과된 AWS IAM Access Key 조회
- **쿼리 파라미터**:
  - `n`: 시간 기준 (기본값: 24시간)
- **응답 형식**:
  ```json
  {
    "stale_keys": [
      {
        "user_id": "string",
        "access_key_id": "string",
        "created_time": "string"
      }
    ]
  }
  ```

## 📊 테스트

### 테스트 범위
- API 테스트: `test_api_stale_keys.py`
  - `/stale-keys` 엔드포인트 테스트
  - 요청/응답 검증
- CSV 파싱 테스트: `test_csv_parsing.py`
  - AWS 키 CSV 파일 파싱 테스트
  - 데이터 유효성 검증
- 키 필터링 테스트: `test_key_filtering.py`
  - 키 필터링 로직 테스트
  - 시간 기준 필터링 검증

## 📝 로깅

### 로깅 설정
- **loguru**를 사용한 로깅 구현
- **특징**:
  - 일자별 로그 파일 생성
  - 로그 레벨별 필터링
  - 에러 추적 정보 포함
  - 비동기 로깅 지원

### 로그 파일 구조
```
logs/
├── iamkeycheck_2025-05-18.log
├── iamkeycheck_2025-05-19.log
└── ...
```

### 로그 레벨
- **DEBUG**: 상세 디버깅 정보
- **INFO**: 일반적인 정보
- **WARNING**: 경고 메시지
- **ERROR**: 에러 메시지
- **CRITICAL**: 심각한 에러

## 🛠 실행 전 요구사항

1. **환경 변수 설정**
   - `.env` 파일에서 다음 변수를 설정해야 함
   ```dotenv
   STAGE=dev
   CSV_PATH=app/api/secrets/
   LOG_LEVEL=INFO
   ```

2. **CSV 파일 위치**
   - `app/api/secrets/` 디렉토리에 CSV 파일 저장
   - `CSV_PATH` 환경 변수로 경로 지정 가능
   - CSV 파일은 반드시 Access key ID와 Secret access key 컬럼을 포함해야 함

3. **로깅 설정**
   - `LOG_LEVEL` 환경 변수로 로그 레벨 설정
   - 로그는 `logs/` 디렉토리에 일자별로 생성됨
   - 에러 로그는 자동으로 추적 정보 포함

## 🚧 주의사항

- AWS IAM Access Key는 민감한 정보이므로 안전한 위치에 저장
- CSV 파일은 `.gitignore`에 포함되어야 함
- 로그 파일은 정기적으로 백업 및 정리 필요
- 모든 에러는 로깅되며, 상세한 에러 메시지는 로그 파일에서 확인 가능

## 🛠 유틸리티

### AWS 키 자동 추출
- `util/extract_aws_creds.py`
  - AWS 키 CSV 파일 자동 추출
  - jq와 python3 필요
  - 자동 환경 변수 설정
