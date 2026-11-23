#!/usr/bin/env python3
import os
import ssl
import sys
import pg8000.native


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
        # Step 1: Add 'superadmin' to enum and COMMIT immediately
        print("Step 1: Adding 'superadmin' enum value...")
        try:
            conn.run("ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'superadmin';")
            conn.run("COMMIT;")
        except Exception as e:
            print(f"Note on enum add: {e}")
            conn.run("ROLLBACK;")

        # Step 2: Now run the remaining SQL (which uses 'superadmin')
        # Filter out the ALTER TYPE statement since it's already done
        remaining_sql = sql_content.replace(
            "ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'superadmin';",
            "-- enum superadmin added and committed",
        )

        print("Step 2: Running remaining schema changes...")
        conn.run(remaining_sql)
        print("Migration 04 executed cleanly!")

        print("\n=== Verifying user_role ENUM ===")
        enums = conn.run("""
            SELECT e.enumlabel 
            FROM pg_type t 
            JOIN pg_enum e ON t.oid = e.enumtypid 
            WHERE t.typname = 'user_role';
        """)
        print("enums:", [e[0] for e in enums])

        print("\n=== Verifying admin profile ===")
        admin_row = conn.run("SELECT id, email, role FROM public.profiles WHERE email = 'admin@kheyrukum.com';")
        print("admin row:", admin_row)

        print("\n=== Verifying public.students columns ===")
        cols = conn.run("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'students'
            ORDER BY ordinal_position;
        """)
        for c in cols:
            print(" ", c)

        print("\n=== Verifying public.monthly_payments columns ===")
        pcols = conn.run("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'monthly_payments'
            ORDER BY ordinal_position;
        """)
        for c in pcols:
            print(" ", c)

        print("\n=== Verifying storage policies for avatars ===")
        spols = conn.run("""
            SELECT policyname, cmd FROM pg_policies
            WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname LIKE '%avatars%';
        """)
        for p in spols:
            print(" ", p)

        print("\n=== Migration 04 complete! ===")
        return True
    except Exception as e:
        print(f"Error executing migration: {e}")
        return False
    finally:
        conn.close()


if __name__ == "__main__":
    success = run_migration()
    sys.exit(0 if success else 1)
