import ssl
import json
import urllib.request
import urllib.error
import pg8000.native

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

conn = pg8000.native.Connection(
    user='postgres.tjhqpzvjzmpyrridtpsj',
    host='aws-1-eu-west-3.pooler.supabase.com',
    port=5432,
    database='postgres',
    password='ustazmuhammedyakut',
    ssl_context=ctx,
    timeout=15
)

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
BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"

login_url = f"{BASE_URL}/auth/v1/token?grant_type=password"
req_login = urllib.request.Request(
    login_url,
    headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
    data=json.dumps({"email": "challenger_teacher_m4@kheyrukum.com", "password": "TestPassword123!"}).encode()
)
try:
    with urllib.request.urlopen(req_login, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        print("LOGIN SUCCESS! Token length:", len(data["access_token"]))
except urllib.error.HTTPError as e:
    print(f"HTTP Error {e.code}: {e.read().decode()}")
