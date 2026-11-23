import json
import os
import urllib.request
import urllib.error
from _db_env import get_supabase_anon_key, get_supabase_url, get_test_password

BASE_URL = get_supabase_url() if os.environ.get("SUPABASE_URL") else "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = get_supabase_anon_key() if os.environ.get("SUPABASE_ANON_KEY") else "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"

email = os.environ.get("KHEYRUKUM_TEST_EMAIL", "m4_teacher_test@kheyrukum.com")
password = get_test_password()

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
