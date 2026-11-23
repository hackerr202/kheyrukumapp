#!/usr/bin/env python3
import os
import sys
import pg8000.native
from _db_env import get_db_connection_params


def run_migration() -> bool:
    sql_path = os.path.join(
        os.path.dirname(__file__),
        "migration_03_user_management_and_fcm.sql",
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
        conn.run(sql_content)
        print("Migration 03 executed cleanly!")

        print("\n=== Verifying public.profiles columns ===")
        for row in conn.run("""
            SELECT column_name, data_type, column_default
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'profiles'
              AND column_name IN ('is_suspended', 'halaqah_id', 'halaqah_name')
            ORDER BY column_name
        """):
            print(" ", row)

        print("\n=== Verifying RPC functions ===")
        for row in conn.run("""
            SELECT routine_name
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name IN ('is_admin', 'consume_invitation_code', 'admin_assign_teacher_halaqah', 'admin_delete_user')
            ORDER BY routine_name
        """):
            print(" ", row)

        return True
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(0 if run_migration() else 1)
