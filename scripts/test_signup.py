import json
import urllib.request
import urllib.error

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"

email = "m4_teacher_test@kheyrukum.com"
password = "TestPassword123!"

signup_url = f"{BASE_URL}/auth/v1/signup"
req = urllib.request.Request(
    signup_url,
    headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
    data=json.dumps({"email": email, "password": password}).encode()
)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        print("Signup response:", resp.status, resp.read().decode())
except urllib.error.HTTPError as e:
    print(f"Signup HTTP Error {e.code}: {e.read().decode()}")
