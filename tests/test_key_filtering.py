from app.service.iamkeycheck.services.impl.stale_key_checker import AccessKeyChecker
from unittest.mock import patch
from datetime import datetime, timedelta

# boto3.Session을 mock하여 AWS 호출 없이 stale key 필터링 로직만 단위테스트
# user_id, threshold 조건 검증

@patch("app.service.iamkeycheck.services.impl.stale_key_checker.boto3.Session")
def test_check_stale_keys(mock_session):
    # IAM get_user, list_access_keys 응답을 mock으로 지정
    mock_iam = mock_session.return_value.client.return_value
    mock_iam.get_user.return_value = {"User": {"UserName": "testuser"}}
    mock_iam.list_access_keys.return_value = {
        "AccessKeyMetadata": [
            {
                "AccessKeyId": "AKIAFAKEKEY123",
                # 48시간 전 생성된 키로 설정
                "CreateDate": datetime.utcnow() - timedelta(hours=48)
            }
        ]
    }

    checker = AccessKeyChecker(csv_dir="tests/sample_secrets/")  # 테스트용 샘플 CSV 디렉토리 지정
    result = checker.check_stale_keys(threshold_hours=24)

    assert isinstance(result, list)  # 결과가 리스트인지 확인
    assert result[0]["user_id"] == "testuser"  # mock된 user_id가 올바르게 추출되는지 확인
