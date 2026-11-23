import pg8000.native
from _db_env import get_db_connection_params

conn = pg8000.native.Connection(**get_db_connection_params(), timeout=15)

users = conn.run("SELECT id, email, role FROM auth.users LIMIT 10")
print("Auth users:", users)

profiles = conn.run("SELECT id, role, full_name, email FROM public.profiles LIMIT 10")
print("Profiles:", profiles)

conn.close()
