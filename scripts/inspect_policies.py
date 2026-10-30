import ssl
import json
import pg8000.native

POOLER_HOST = "aws-1-eu-west-3.pooler.supabase.com"
DB_USER = "postgres.tjhqpzvjzmpyrridtpsj"
DB_PASS = "ustazmuhammedyakut"
DB_NAME = "postgres"

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

# Connect to Session pooler on port 5432
conn = pg8000.native.Connection(
    user=DB_USER,
    host=POOLER_HOST,
    port=5432,
    database=DB_NAME,
    password=DB_PASS,
    ssl_context=ctx,
    timeout=15
)

print("--- Announcements Columns ---")
cols = conn.run(
    "SELECT column_name, data_type, is_nullable, column_default "
    "FROM information_schema.columns "
    "WHERE table_name = 'announcements' ORDER BY ordinal_position"
)
for c in cols:
    print(c)

print("\n--- Announcements RLS and Policies ---")
rls_info = conn.run(
    "SELECT relname, relrowsecurity, relforcerowsecurity "
    "FROM pg_class WHERE relname = 'announcements'"
)
print("RLS status:", rls_info)

policies = conn.run(
    "SELECT policyname, permissive, roles, cmd, qual, with_check "
    "FROM pg_policies WHERE tablename = 'announcements'"
)
for p in policies:
    print(p)

print("\n--- All Policies Across Key Tables ---")
all_pols = conn.run(
    "SELECT tablename, policyname, roles, cmd, qual "
    "FROM pg_policies WHERE tablename IN ('announcements', 'halaqahs', 'students', 'parent_students', 'messages') "
    "ORDER BY tablename, policyname"
)
for p in all_pols:
    print(p)

conn.close()
