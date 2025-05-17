# Force update for git tracking
from typing import List, Dict
from datetime import datetime, timedelta
import csv
import boto3
import os

class AccessKeyChecker:
    def __init__(self, csv_path: str = None):
        self.csv_path = csv_path or os.getenv("CSV_PATH", "app/secrets/applicant_accessKeys.csv")

    def load_credentials(self) -> List[Dict[str, str]]:
        with open(self.csv_path, newline='') as f:
            reader = csv.DictReader(f)
            return list(reader)

    def check_stale_keys(self, threshold_hours: int) -> List[Dict[str, str]]:
        result = []
        now = datetime.utcnow()

        for cred in self.load_credentials():
            access_key = cred.get("Access key ID")
            secret_key = cred.get("Secret access key")

            if not access_key or not secret_key:
                continue  # 유효하지 않은 행은 무시

            session = boto3.Session(
                aws_access_key_id=access_key,
                aws_secret_access_key=secret_key
            )
            try:
                iam = session.client("iam")
                user = iam.get_user()
                username = user["User"]["UserName"]

                keys = iam.list_access_keys(UserName=username)
                for k in keys["AccessKeyMetadata"]:
                    create_time = k["CreateDate"]
                    elapsed = now - create_time.replace(tzinfo=None)

                    if elapsed > timedelta(hours=threshold_hours):
                        result.append({
                            "user_id": username,
                            "access_key_id": k["AccessKeyId"]
                        })

            except Exception as e:
                print(f"[WARN] Failed to check key {access_key}: {e}")

        return result
