import urllib.request
import urllib.error
import json

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"

bucket = "announcement_attachments"
path = "challenge/test.bin"

# 1. Without apikey and without auth:
url = f"{BASE_URL}/storage/v1/object/{bucket}/{path}"
req1 = urllib.request.Request(url, data=b"test", method="POST")
try:
    with urllib.request.urlopen(req1) as r:
        print("Req1 success:", r.status)
except urllib.error.HTTPError as e:
    print(f"Req1 (zero headers): HTTP {e.code}: {e.read().decode()}")

# 2. With apikey only (anonymous client):
req2 = urllib.request.Request(url, data=b"test", headers={"apikey": ANON_KEY, "Content-Type": "application/octet-stream"}, method="POST")
try:
    with urllib.request.urlopen(req2) as r:
        print("Req2 success:", r.status)
except urllib.error.HTTPError as e:
    print(f"Req2 (apikey only): HTTP {e.code}: {e.read().decode()}")
