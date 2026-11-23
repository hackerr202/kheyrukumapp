import json
import urllib.request
import pg8000.native
from _db_env import (
    get_db_connection_params,
    get_supabase_anon_key,
    get_supabase_url,
    get_test_password,
)

conn = pg8000.native.Connection(**get_db_connection_params(), timeout=15)

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
supabase_url = get_supabase_url()
anon_key = get_supabase_anon_key()
test_password = get_test_password()

req = urllib.request.Request(
    f'{supabase_url}/auth/v1/token?grant_type=password',
    headers={
        'apikey': anon_key,
        'Content-Type': 'application/json'
    },
    data=json.dumps({
        'email': 'challenger_test_m1@kheyrukum.com',
        'password': test_password
    }).encode()
)

with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read())
    token = data['access_token']
    print(f"AUTHENTICATED JWT SUCCESS! Length: {len(token)}")
    with open('test_token.txt', 'w') as f:
        f.write(token)
