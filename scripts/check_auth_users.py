import ssl
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

users = conn.run("SELECT id, email, role FROM auth.users LIMIT 10")
print("Auth users:", users)

profiles = conn.run("SELECT id, role, full_name, email FROM public.profiles LIMIT 10")
print("Profiles:", profiles)

conn.close()
