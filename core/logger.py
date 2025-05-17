from loguru import logger
import sys

# 기존 loguru의 기본 핸들러를 제거 (중복 출력 방지)
logger.remove()

# 표준 출력(sys.stdout)으로 로그를 출력하도록 새 핸들러 추가
# - 로그 레벨: INFO 이상
# - 출력 포맷: [YYYY-MM-DD HH:mm:ss] [LEVEL] 메시지
logger.add(sys.stdout, level="INFO", format="[{time:YYYY-MM-DD HH:mm:ss}] [{level}] {message}")

# 루트 디렉토리에 일자별 로그 파일 생성 (app-YYMMDD.log)
# - 매일 파일 분리(rotate)
# - 7일 이후 자동 삭제(retention)
# - 파일에도 콘솔과 동일한 포맷 적용
# - 파일 로그는 INFO 레벨 이상 기록
import os
from datetime import datetime
# 로그 디렉토리(log)가 없으면 생성
log_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'log')
os.makedirs(log_dir, exist_ok=True)
logfile_path = os.path.join(log_dir, f"app-{datetime.now().strftime('%y%m%d')}.log")
logger.add(
    logfile_path,
    level="INFO",
    format="[{time:YYYY-MM-DD HH:mm:ss}] [{level}] {message}",
    rotation="00:00",   # 매일 자정마다 새 파일로 분리
    retention="7 days", # 7일 이후 자동 삭제
    encoding="utf-8"
)

"""
loguru 기반의 프로젝트 전역 로거 설정 파일입니다.
- logger를 import하여 프로젝트 어디서나 일관된 방식으로 로그를 남길 수 있습니다.
- 로그 레벨, 포맷, 출력 대상(콘솔, 파일 등)도 여기서 통제합니다.
- 필요 시 logger.info(), logger.error(), logger.debug() 등으로 사용하세요.
- 파일 로그(app-YYMMDD.log)는 루트 디렉토리에 생성되며 7일간 보관됩니다.
"""
