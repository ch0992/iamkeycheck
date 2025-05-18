import os
from app.service.iamkeycheck.services.stale_key_checker import AccessKeyChecker

# 여러 개의 CSV 파일을 파싱하여 올바른 리스트를 반환하는지 검증하는 테스트
# - 샘플 CSV 파일은 conftest.py의 fixture가 app/tests/sample_secrets/test.csv로 자동 생성/정리됨
# - 각 딕셔너리에 필수 컬럼(Access key ID, Secret access key)이 포함되어야 함

def test_csv_parsing_multiple_files():
    # 현재 파일(app/tests/test_csv_parsing.py) 기준으로 sample_secrets 경로 지정
    base_dir = os.path.dirname(__file__)
    sample_dir = os.path.join(base_dir, "sample_secrets")
    checker = AccessKeyChecker(csv_dir=sample_dir)  # 테스트용 샘플 CSV 디렉토리 지정
    creds = checker.load_all_credentials()  # CSV 파일 파싱
    assert isinstance(creds, list)  # 반환값이 리스트인지 확인
    # 모든 딕셔너리에 필수 키가 포함되어 있는지 확인
    assert all("Access key ID" in c and "Secret access key" in c for c in creds)