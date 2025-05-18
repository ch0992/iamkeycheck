from fastapi import APIRouter, Query, HTTPException
from app.service.iamkeycheck.services.stale_key_checker import AccessKeyChecker
from app.core.logger import logger

# FastAPI 라우터 인스턴스 생성
router = APIRouter()

from fastapi import Request

@router.get("/stale-keys")
async def get_stale_keys(request: Request, n: int = Query(24, description="N시간 이상 경과된 AccessKey를 필터링합니다")):
    """
    N시간(threshold) 이상 사용된 AWS Access Key(즉, stale key)를 필터링하여 반환하는 API 엔드포인트입니다.
    - 클라이언트는 쿼리 파라미터 n(기본값 24, 단위: 시간)을 통해 임계값을 지정할 수 있습니다.
    - 내부적으로 AccessKeyChecker를 사용하여 CSV에서 키를 로드하고, AWS IAM API를 통해 각 키의 생성일을 확인합니다.
    Args:
        n (int): 임계값(시간). 이 값보다 오래된 키만 반환됩니다. (기본값: 24)
    Returns:
        dict: {"stale_keys": [...]}
    Raises:
        HTTPException: 내부 처리 중 예외 발생 시 500 에러와 상세 메시지를 반환합니다.
    """
    import traceback
    try:
        checker = AccessKeyChecker()
        result = checker.check_stale_keys(n)
        # 1. 감사/보안 로그: 요청 헤더, IP, User-Agent
        ip = request.client.host if request.client else "unknown"
        user_agent = request.headers.get("user-agent", "")
        headers_for_audit = {k: v for k, v in request.headers.items() if k.lower() not in ["authorization", "cookie"]}
        logger.info(f"[AUDIT][HEADER] ip={ip}, headers={headers_for_audit}, user-agent={user_agent}")
        # 2. 감사 summary 로그 (status/result, 마스킹 포함)
        def mask_key(key):
            if not key or len(key) < 5:
                return "****"
            return key[:2] + '*' * (len(key)-4) + key[-2:]
        masked_list = [f"user_id={stale['user_id']}, access_key_id={mask_key(stale['access_key_id'])}" for stale in result]
        logger.info(f"[AUDIT] Total checked: status_code=200, threshold={n}, result_count={len(result)}, stale_keys=[{'; '.join(masked_list)}]")
        return {"stale_keys": result}
    except Exception as e:
        # 예외 발생 시 HTTP 500 에러로 변환하여 클라이언트에 반환
        # 1. 감사/보안 로그: 요청 헤더, IP, User-Agent (에러 상황에도 남김)
        ip = request.client.host if request.client else "unknown"
        user_agent = request.headers.get("user-agent", "")
        headers_for_audit = {k: v for k, v in request.headers.items() if k.lower() not in ["authorization", "cookie"]}
        logger.info(f"[AUDIT][HEADER] ip={ip}, headers={headers_for_audit}, user-agent={user_agent}")
        # 2. 에러 결과 요약 로그
        logger.error(f"[AUDIT][ERROR] /stale-keys API error: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))
