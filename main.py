from fastapi import FastAPI
from core.logger import logger
from core.config import Settings

app = FastAPI()
settings = Settings()

@app.get("/health")
def health_check():
    logger.info("Health check endpoint called.")
    return {"status": "ok"}

# 실제 라우터는 app/service/iamkeycheck/api/routes에서 import하여 등록 예정

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
