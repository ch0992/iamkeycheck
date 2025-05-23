import os
from pydantic import BaseModel

class Settings(BaseModel):
    """
    Settings 클래스는 환경 변수 기반의 설정 관리 기능을 제공합니다.
    - .env 파일 지원 없이, 시스템 환경변수에서 값을 직접 읽어옵니다.
    - FastAPI, 서비스 로직 등에서 공통 설정을 일관성 있게 참조할 수 있습니다.
    속성 설명:
        STAGE: 현재 서비스 환경 (예: dev, prod 등)
        CSV_PATH: Access Key CSV 파일 경로 (환경변수로 덮어쓸 수 있음)
        AWS_ACCESS_KEY_ID: AWS API 호출용 기본 Access Key (테스트/운영 환경에서 사용)
        AWS_SECRET_ACCESS_KEY: AWS API 호출용 기본 Secret Key
        LOG_LEVEL: 로깅 레벨 (예: INFO, DEBUG)
        IMAGE_TAG: 배포 이미지 태그 (configmap/app_config에서 주입)
    """
    STAGE: str = os.getenv("STAGE", "dev")
    CSV_PATH: str = os.getenv("CSV_PATH", "app/api/secrets/")
    AWS_ACCESS_KEY_ID: str = os.getenv("AWS_ACCESS_KEY_ID")
    AWS_SECRET_ACCESS_KEY: str = os.getenv("AWS_SECRET_ACCESS_KEY")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    IMAGE_TAG: str = os.getenv("IMAGE_TAG")
