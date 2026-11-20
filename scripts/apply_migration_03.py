#!/usr/bin/env python3
import os
import ssl
import sys
import pg8000.native


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

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    targets = [
        ("aws-1-eu-west-3.pooler.supabase.com", 5432, "postgres.tjhqpzvjzmpyrridtpsj"),
        ("aws-1-eu-west-3.pooler.supabase.com", 6543, "postgres.tjhqpzvjzmpyrridtpsj"),
        ("db.tjhqpzvjzmpyrridtpsj.supabase.co", 5432, "postgres"),
    ]

    conn = None
    for host, port, user in targets:
        try:
            print(f"Connecting to {host}:{port}...", end=" ", flush=True)
            conn = pg8000.native.Connection(
                user=user,
                host=host,
                port=port,
                database="postgres",
                password="ustazmuhammedyakut",
                ssl_context=ctx,
                timeout=15,
            )
            print("CONNECTED")
            break
        except Exception as e:
            print(f"failed ({e})")

    if conn is None:
        print("Error: Could not connect to Supabase PostgreSQL.")
        return False

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

        print("\n=== Verifying public.profiles RLS policies ===")
        for row in conn.run("""
            SELECT policyname, cmd, qual
            FROM pg_policies
            WHERE schemaname = 'public' AND tablename = 'profiles'
            ORDER BY policyname
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

        print("\n=== Verifying teacher profiles + halaqah linkage ===")
        for row in conn.run("""
            SELECT left(id::text, 8), full_name, is_suspended, left(coalesce(halaqah_id::text,'none'), 8), halaqah_name
            FROM public.profiles
            WHERE role = 'teacher'
            ORDER BY created_at DESC
        """):
            print(" ", row)

        print("\n=== Verifying user_device_tokens provider counts ===")
        for row in conn.run("""
            SELECT coalesce(provider, 'null'), COUNT(*)
            FROM public.user_device_tokens
            GROUP BY 1
        """):
            print(" ", row)

        return True
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(0 if run_migration() else 1)
