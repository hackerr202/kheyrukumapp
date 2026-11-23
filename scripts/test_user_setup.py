import json
import os
import urllib.request
import urllib.error
import pg8000.native
from _db_env import (
    get_db_connection_params,
    get_supabase_anon_key,
    get_supabase_url,
    get_test_password,
)

conn = pg8000.native.Connection(**get_db_connection_params(), timeout=15)

conn.run("""
    UPDATE auth.users
    SET 
        confirmation_token = '',
        recovery_token = '',
        email_change_token_new = '',
        email_change = '',
        email_change_token_current = '',
        phone_change = '',
        phone_change_token = '',
        reauthentication_token = ''
    WHERE email = 'challenger_teacher_m4@kheyrukum.com';
""")
conn.close()

# Now test login
BASE_URL = get_supabase_url() if os.environ.get("SUPABASE_URL") else "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = get_supabase_anon_key() if os.environ.get("SUPABASE_ANON_KEY") else "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"

login_url = f"{BASE_URL}/auth/v1/token?grant_type=password"
req_login = urllib.request.Request(
    login_url,
    headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
    data=json.dumps({"email": "challenger_teacher_m4@kheyrukum.com", "password": get_test_password()}).encode()
)
try:
    with urllib.request.urlopen(req_login, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        print("LOGIN SUCCESS! Token length:", len(data["access_token"]))
except urllib.error.HTTPError as e:
    print(f"HTTP Error {e.code}: {e.read().decode()}")
