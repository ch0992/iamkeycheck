from typing import List, Dict
from datetime import datetime, timedelta
import csv
import boto3
import os
import glob
from core.logger import logger

class AccessKeyChecker:
    """
    AccessKeyChecker는 지정된 디렉토리 내의 AWS Access Key CSV 파일들을 읽고,
    각 키의 상태(생성 후 경과 시간 등)를 확인하는 기능을 제공합니다.
    """
    def __init__(self, csv_dir: str = None):
        """
        클래스 생성자. CSV 파일이 위치한 디렉토리를 지정하거나,
        환경 변수 CSV_PATH가 있으면 이를 사용합니다.
        Args:
            csv_dir (str, optional): CSV 파일이 위치한 디렉토리 경로. 기본값은 None이며, 이 경우 환경 변수를 사용합니다.
        """
        self.csv_dir = csv_dir or os.getenv("CSV_PATH", "app/secrets/")

    def load_all_credentials(self) -> List[Dict[str, str]]:
        """
        지정된 디렉토리 내의 모든 .csv 파일에서 AWS Access Key 정보를 추출합니다.
        각 파일은 AWS 콘솔에서 다운로드한 형식(헤더: 'Access key ID', 'Secret access key')이어야 합니다.
        Returns:
            List[Dict[str, str]]: 각 키 정보를 담은 딕셔너리의 리스트
        """
        logger.debug(f"[DEBUG] csv_dir: {self.csv_dir}")
        all_creds = []
        # 지정된 디렉토리 내의 모든 .csv 파일 경로 탐색
        file_paths = glob.glob(os.path.join(self.csv_dir, "*.csv"))

        for path in file_paths:
            try:
                with open(path, newline='') as f:
                    reader = csv.DictReader(f)
                    creds = list(reader)
                    # 필수 컬럼이 모두 존재하는 경우에만 추가
                    if creds and "Access key ID" in creds[0] and "Secret access key" in creds[0]:
                        all_creds.extend(creds)
                    else:
                        pass
            except Exception as e:
                pass

        return all_creds

    def check_stale_keys(self, threshold_hours: int) -> List[Dict[str, str]]:
        """
        Access Key의 생성 후 경과 시간이 threshold_hours(시간) 이상인 키를 필터링합니다.
        각 키에 대해 AWS IAM API를 호출하여 실제 생성일 및 상태를 확인합니다.
        Args:
            threshold_hours (int): 경과 시간(시간 단위) 임계값
        Returns:
            List[Dict[str, str]]: 조건에 해당하는 (user_id, access_key_id) 딕셔너리 리스트
        """
        result = []
        now = datetime.utcnow()  # 현재 UTC 시간

        for cred in self.load_all_credentials():
            access_key = cred.get("Access key ID")
            secret_key = cred.get("Secret access key")

            # 필수 정보가 없으면 건너뜀 (감사 로그)
            if not access_key or not secret_key:

                continue

            # boto3 세션 생성 (각 키 쌍마다)
            session = boto3.Session(
                aws_access_key_id=access_key,
                aws_secret_access_key=secret_key
            )
            try:
                iam = session.client("iam")
                # 현재 키의 소유자(사용자명) 조회
                user = iam.get_user()
                username = user["User"]["UserName"]

                # 해당 사용자의 모든 Access Key 메타데이터 조회
                keys = iam.list_access_keys(UserName=username)
                for k in keys["AccessKeyMetadata"]:
                    create_time = k["CreateDate"]  # Access Key 생성일 (datetime)
                    elapsed = now - create_time.replace(tzinfo=None)  # 경과 시간 계산
                    # 임계값을 초과한(stale) 키만 결과에 추가
                    if elapsed > timedelta(hours=threshold_hours):
                        result.append({
                            "user_id": username,
                            "access_key_id": k["AccessKeyId"]
                        })

            except Exception as e:
                # IAM API 호출 실패 시 경고 로그는 남김 (운영 감사/장애 추적 목적)
                logger.warning(f"[WARN] Failed to check key {access_key}: {e}")

        return result
