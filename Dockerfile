# syntax=docker/dockerfile:1
FROM python:3.11-slim

WORKDIR /app

# 시스템 패키지 설치 (예: gcc, libpq-dev 등 필요시 추가)
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 파이썬 패키지 설치
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 앱 소스 복사
COPY . .

# 환경 변수 파일 위치 지정
ENV PYTHONPATH=/app

# FastAPI 실행
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
