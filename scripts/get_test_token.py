import ssl
import json
import urllib.request
import pg8000.native

POOLER_HOST = "aws-1-eu-west-3.pooler.supabase.com"
DB_USER = "postgres.tjhqpzvjzmpyrridtpsj"
DB_PASS = "ustazmuhammedyakut"
DB_NAME = "postgres"

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

conn = pg8000.native.Connection(
    user=DB_USER,
    host=POOLER_HOST,
    port=5432,
    database=DB_NAME,
    password=DB_PASS,
    ssl_context=ctx,
    timeout=15
)

# Confirm challenger email and ensure profile exists
conn.run("UPDATE auth.users SET email_confirmed_at = NOW() WHERE email = 'challenger_test_m1@kheyrukum.com'")
users = conn.run("SELECT id, email FROM auth.users WHERE email = 'challenger_test_m1@kheyrukum.com'")
user_id = str(users[0][0])
print(f"Confirmed user {user_id}")

# Upsert profile with admin role so it has full privileges for challenging
conn.run(
    f"INSERT INTO public.profiles (id, role, full_name, email) "
    f"VALUES ('{user_id}', 'admin'::user_role, 'Challenger Admin', 'challenger_test_m1@kheyrukum.com') "
    f"ON CONFLICT (id) DO UPDATE SET role = 'admin'::user_role"
)
conn.close()

# Sign in to get access token
req = urllib.request.Request(
    'https://tjhqpzvjzmpyrridtpsj.supabase.co/auth/v1/token?grant_type=password',
    headers={
        'apikey': 'sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g',
        'Content-Type': 'application/json'
    },
    data=json.dumps({
        'email': 'challenger_test_m1@kheyrukum.com',
        'password': 'TestPassword123!'
    }).encode()
)

with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read())
    token = data['access_token']
    print(f"AUTHENTICATED JWT SUCCESS! Length: {len(token)}")
    with open('test_token.txt', 'w') as f:
        f.write(token)
