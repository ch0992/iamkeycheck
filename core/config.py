from pydantic import BaseSettings

class Settings(BaseSettings):
    """
    Settings 클래스는 pydantic의 BaseSettings를 상속받아, 환경 변수 기반의 설정 관리 기능을 제공합니다.
    - .env 파일 또는 시스템 환경변수에서 값을 자동으로 로드합니다.
    - FastAPI, 서비스 로직 등에서 공통 설정을 일관성 있게 참조할 수 있습니다.
    속성 설명:
        STAGE: 현재 서비스 환경 (예: dev, prod 등)
        CSV_PATH: Access Key CSV 파일 경로 (환경변수로 덮어쓸 수 있음)
        AWS_ACCESS_KEY_ID: AWS API 호출용 기본 Access Key (테스트/운영 환경에서 사용)
        AWS_SECRET_ACCESS_KEY: AWS API 호출용 기본 Secret Key
        LOG_LEVEL: 로깅 레벨 (예: INFO, DEBUG)
    """
    STAGE: str = "dev"
    CSV_PATH: str = "/app/secrets/applicant_accessKeys.csv"
    AWS_ACCESS_KEY_ID: str = "dummy"
    AWS_SECRET_ACCESS_KEY: str = "dummy"
    LOG_LEVEL: str = "INFO"

    class Config:
        # 환경 변수 파일(.env)에서 값을 자동으로 읽어오도록 설정
        env_file = ".env"
        env_file_encoding = "utf-8"
