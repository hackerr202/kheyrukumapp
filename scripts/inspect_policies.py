import pg8000.native
from _db_env import get_db_connection_params

conn = pg8000.native.Connection(**get_db_connection_params(), timeout=15)

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
