from fastapi import FastAPI
from app.core.logger import logger
from app.core.config import Settings
from app.api.routes import stale_key_route

# FastAPI 애플리케이션 인스턴스 생성
# 전체 API의 엔트리포인트가 되는 객체입니다.
app = FastAPI()

# 환경설정 객체 생성 (예: 환경변수, 설정값 등 관리)
settings = Settings()

# Access Key 관련 라우터(stale-keys 등)를 앱에 등록
app.include_router(stale_key_route.router)

@app.get("/health")
def health_check():
    """
    서비스 상태 확인용 헬스 체크 엔드포인트
    - 외부 모니터링/로드밸런서 등이 이 경로를 호출해 서비스가 살아있는지 확인 가능
    Returns:
        dict: {"status": "ok"}
    """
    logger.info("Health check endpoint called.")
    return {"status": "ok"}

# 실제 라우터는 app/service/iamkeycheck/api/routes에서 import하여 등록 예정
# (위에서 이미 include_router로 등록됨)

if __name__ == "__main__":
    # 개발/테스트 환경에서 직접 실행할 때 진입점
    # uvicorn 개발 서버를 실행하여 FastAPI 앱을 띄움
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
