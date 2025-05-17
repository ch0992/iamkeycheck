# 공통 fixture 설정 스텁

import pytest
import os
import shutil

# 모든 테스트 세션에서 공통으로 샘플 CSV를 준비하는 fixture
# 테스트 시작 전 sample_secrets 디렉토리와 CSV 파일 생성
# 테스트 종료 후 자동 삭제

@pytest.fixture(scope="session", autouse=True)
def prepare_sample_csv():
    # 샘플 CSV 파일 생성
    os.makedirs("tests/sample_secrets", exist_ok=True)
    with open("tests/sample_secrets/test.csv", "w") as f:
        f.write("Access key ID,Secret access key\n")
        f.write("AKIAFAKE,abc123fakekey\n")
    yield  # 테스트 실행
    # 샘플 CSV 파일 삭제
    shutil.rmtree("tests/sample_secrets", ignore_errors=True)  # 정리
