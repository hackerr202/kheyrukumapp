import urllib.request
import urllib.error
import json
import time

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"
with open("test_token.txt") as f:
    token = f.read().strip()

bucket = "announcement_attachments"
path = f"challenge/cache_test_{int(time.time())}.bin"
content1 = b"INITIAL_CONTENT"
content2 = b"UPDATED_CONTENT"

# 1. Upload initial
req1 = urllib.request.Request(
    f"{BASE_URL}/storage/v1/object/{bucket}/{path}",
    data=content1,
    headers={"apikey": ANON_KEY, "Authorization": f"Bearer {token}", "Content-Type": "application/octet-stream"},
    method="POST"
)
with urllib.request.urlopen(req1) as r:
    print("Initial upload:", r.status)

# 2. Public GET
pub_url = f"{BASE_URL}/storage/v1/object/public/{bucket}/{path}"
with urllib.request.urlopen(urllib.request.Request(pub_url)) as r:
    b1 = r.read()
    print("Pub get 1 content:", b1, "Cache headers:", r.headers.get("cf-cache-status"), r.headers.get("cache-control"))

# 3. Upsert
req2 = urllib.request.Request(
    f"{BASE_URL}/storage/v1/object/{bucket}/{path}",
    data=content2,
    headers={"apikey": ANON_KEY, "Authorization": f"Bearer {token}", "Content-Type": "application/octet-stream", "x-upsert": "true"},
    method="POST"
)
with urllib.request.urlopen(req2) as r:
    print("Upsert status:", r.status, r.read().decode())

# 4. Public GET immediately
with urllib.request.urlopen(urllib.request.Request(pub_url)) as r:
    b2 = r.read()
    print("Pub get 2 (same URL) content:", b2, "Cache:", r.headers.get("cf-cache-status"))

# 5. Public GET with cache buster query parameter ?t=...
with urllib.request.urlopen(urllib.request.Request(f"{pub_url}?t={int(time.time())}")) as r:
    b3 = r.read()
    print("Pub get 3 (with ?t=...) content:", b3, "Cache:", r.headers.get("cf-cache-status"))

# Cleanup
urllib.request.urlopen(urllib.request.Request(f"{BASE_URL}/storage/v1/object/{bucket}/{path}", headers={"apikey": ANON_KEY, "Authorization": f"Bearer {token}"}, method="DELETE"))
