from fastapi.testclient import TestClient
from main import app

# FastAPI 테스트 클라이언트 생성
client = TestClient(app)

# /stale-keys API가 정상적으로 200을 반환하고, stale_keys가 리스트로 포함되는지 검증

def test_api_stale_keys_success():
    response = client.get("/stale-keys?n=24")  # n=24 파라미터로 호출
    assert response.status_code == 200  # 정상 응답 코드
    assert "stale_keys" in response.json()  # 응답에 stale_keys 키가 있는지 확인
    assert isinstance(response.json()["stale_keys"], list)  # stale_keys 값이 리스트인지 확인
