import pytest
import os
import shutil

# 모든 테스트 세션에서 공통으로 샘플 CSV를 준비하는 fixture
# - 테스트 시작 전: app/tests/sample_secrets 디렉토리와 test.csv 파일을 생성
# - 테스트 종료 후: sample_secrets 디렉토리 전체를 자동 삭제
# - 항상 conftest.py가 위치한 디렉토리(app/tests) 기준으로 동작하므로, 어디서 pytest를 실행해도 안전

@pytest.fixture(scope="session", autouse=True)
def prepare_sample_csv():
    # 1. 샘플 CSV 파일 및 디렉토리 생성
    base_dir = os.path.dirname(__file__)  # 현재 파일(app/tests/conftest.py) 기준
    sample_dir = os.path.join(base_dir, "sample_secrets")
    os.makedirs(sample_dir, exist_ok=True)
    csv_path = os.path.join(sample_dir, "test.csv")
    with open(csv_path, "w") as f:
        from app.service.iamkeycheck.services.stale_key_checker import AccessKeyChecker
        f.write("Access key ID,Secret access key\n")
        f.write("AKIAFAKE,abc123fakekey\n")
    yield  # 테스트 실행
    # 2. 테스트 종료 후 샘플 CSV 디렉토리 삭제(정리)
    shutil.rmtree(sample_dir, ignore_errors=True)