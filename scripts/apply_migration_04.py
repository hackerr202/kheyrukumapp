#!/usr/bin/env python3
import os
import sys
import pg8000.native
from _db_env import get_db_connection_params


def run_migration() -> bool:
    sql_path = os.path.join(
        os.path.dirname(__file__),
        "migration_04_roles_fees_avatars.sql",
    )
    if not os.path.exists(sql_path):
        print(f"Error: SQL file not found at {sql_path}")
        return False

    with open(sql_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    db_params = get_db_connection_params()
    print(f"Connecting to {db_params['host']}:{db_params['port']}...", end=" ", flush=True)
    conn = pg8000.native.Connection(**db_params, timeout=15)
    print("CONNECTED")

    try:
        print("Step 1: Adding 'superadmin' enum value...")
        try:
            conn.run("ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'superadmin';")
            conn.run("COMMIT;")
        except Exception as e:
            print(f"Note on enum add: {e}")
            conn.run("ROLLBACK;")

        remaining_sql = sql_content.replace(
            "ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'superadmin';",
            "-- enum superadmin added and committed",
        )

        print("Step 2: Running remaining schema changes...")
        conn.run(remaining_sql)
        print("Migration 04 executed cleanly!")
        return True
    except Exception as e:
        print(f"Error executing migration: {e}")
        return False
    finally:
        conn.close()


if __name__ == "__main__":
    success = run_migration()
    sys.exit(0 if success else 1)
