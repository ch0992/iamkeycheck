#!/usr/bin/env python3
import sys
import json
from pathlib import Path

# 기존 AccessKeyChecker 재사용
sys.path.append(str(Path(__file__).resolve().parent.parent.parent))
from app.service.iamkeycheck.services.stale_key_checker import AccessKeyChecker

checker = AccessKeyChecker()
creds = checker.load_all_credentials()
if creds:
    # 첫 번째 키만 사용
    print(json.dumps({
        "AWS_ACCESS_KEY_ID": creds[0]["Access key ID"],
        "AWS_SECRET_ACCESS_KEY": creds[0]["Secret access key"]
    }))
else:
    print(json.dumps({}))
    sys.exit(1)
