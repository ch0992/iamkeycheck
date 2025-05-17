from pydantic import BaseSettings

class Settings(BaseSettings):
    STAGE: str = "dev"
    CSV_PATH: str = "/app/secrets/applicant_accessKeys.csv"
    AWS_ACCESS_KEY_ID: str = "dummy"
    AWS_SECRET_ACCESS_KEY: str = "dummy"
    LOG_LEVEL: str = "INFO"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
