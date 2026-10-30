#!/usr/bin/env python3
"""
Executes scripts/migration_02_security_fixes.sql against live Supabase PostgreSQL
and performs comprehensive verification of all hardened policies, conversation columns,
and storage permissions.
"""

import os
import sys
import ssl
import pg8000.native

POOLER_HOST = "aws-1-eu-west-3.pooler.supabase.com"
DB_USER = "postgres.tjhqpzvjzmpyrridtpsj"
DB_PASS = "ustazmuhammedyakut"
DB_NAME = "postgres"

def main():
    print("=" * 70)
    print("KHEYRUKUM MIGRATION 02: SECURITY & RLS HARDENING RUNNER")
    print("=" * 70)

    sql_path = os.path.join(os.path.dirname(__file__), "migration_02_security_fixes.sql")
    if not os.path.exists(sql_path):
        print(f"[ERROR] Migration file not found at: {sql_path}")
        sys.exit(1)

    with open(sql_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    print(f"Loaded migration script ({len(sql_content)} bytes)")

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    targets = [
        {"host": POOLER_HOST, "port": 6543, "label": f"{POOLER_HOST}:6543 (Transaction Mode)"},
        {"host": POOLER_HOST, "port": 5432, "label": f"{POOLER_HOST}:5432 (Session Mode)"},
    ]

    con = None
    connected_target = None
    for t in targets:
        print(f"Connecting to {t['label']}...", end=" ", flush=True)
        try:
            con = pg8000.native.Connection(
                user=DB_USER,
                host=t["host"],
                port=t["port"],
                database=DB_NAME,
                password=DB_PASS,
                ssl_context=ctx,
                timeout=20,
            )
            print("CONNECTED!")
            connected_target = t
            break
        except Exception as e:
            print(f"Failed: {e}")

    if not con:
        print("[ERROR] Could not connect to Supabase PostgreSQL.")
        sys.exit(1)

    try:
        print("\nExecuting migration_02_security_fixes.sql...")
        con.run(sql_content)
        print("[SUCCESS] Migration 02 executed successfully!")

        print("\n--- Verifying Schema Changes & Hardened Policies ---")

        # 1. Verify conversations columns
        conv_cols = con.run("""
            SELECT column_name, data_type, column_default
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'conversations'
            AND column_name IN ('participant_ids', 'participant_names', 'unread_count', 'is_pinned')
            ORDER BY column_name;
        """)
        print(f"1. Conversations columns added ({len(conv_cols)}/4):")
        for col in conv_cols:
            print(f"   - {col[0]}: {col[1]} (default: {col[2]})")
        assert len(conv_cols) == 4, f"Expected 4 new conversation columns, got {len(conv_cols)}"

        # 2. Verify conversation_participants RLS & policies
        cp_pols = con.run("""
            SELECT policyname, permissive, roles, cmd, qual
            FROM pg_policies
            WHERE schemaname = 'public' AND tablename = 'conversation_participants';
        """)
        print(f"\n2. conversation_participants policies ({len(cp_pols)} policies):")
        for p in cp_pols:
            print(f"   - {p[0]} ({p[3]})")
        assert len(cp_pols) >= 2, f"Expected at least 2 policies on conversation_participants, got {len(cp_pols)}"

        # 3. Verify announcements hardened policies (NO permissive delete/insert for non-admins)
        ann_pols = con.run("""
            SELECT policyname, permissive, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'public' AND tablename = 'announcements';
        """)
        print(f"\n3. announcements policies ({len(ann_pols)} policies):")
        for p in ann_pols:
            print(f"   - {p[0]} ({p[3]})")
            # Verify no policy with qual = 'true' for DELETE or INSERT
            if p[3] in ('DELETE', 'UPDATE'):
                assert p[4] != 'true', f"Policy {p[0]} on announcements is still overly permissive!"
            if p[3] == 'INSERT':
                assert p[5] != 'true', f"Policy {p[0]} on announcements is still overly permissive!"

        # 4. Verify halaqahs hardened policies (No duplicate permissive policy)
        hal_pols = con.run("""
            SELECT policyname, permissive, roles, cmd, qual
            FROM pg_policies
            WHERE schemaname = 'public' AND tablename = 'halaqahs';
        """)
        print(f"\n4. halaqahs policies ({len(hal_pols)} policies):")
        for p in hal_pols:
            print(f"   - {p[0]} ({p[3]})")
            if p[0] == "Admins can manage halaqahs":
                raise AssertionError("Overly permissive policy 'Admins can manage halaqahs' still exists!")

        # 5. Verify students hardened policies
        stu_pols = con.run("""
            SELECT policyname, permissive, roles, cmd, qual
            FROM pg_policies
            WHERE schemaname = 'public' AND tablename = 'students';
        """)
        print(f"\n5. students policies ({len(stu_pols)} policies):")
        for p in stu_pols:
            print(f"   - {p[0]} ({p[3]})")
            if p[0] == "Admins can manage students":
                raise AssertionError("Overly permissive policy 'Admins can manage students' still exists!")

        # 6. Verify storage.objects policies
        st_pols = con.run("""
            SELECT policyname, permissive, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'storage' AND tablename = 'objects';
        """)
        print(f"\n6. storage.objects policies ({len(st_pols)} policies):")
        policy_names = [p[0] for p in st_pols]
        for name in policy_names:
            print(f"   - {name}")

        assert "Public read chat attachments" in policy_names, "Missing 'Public read chat attachments'"
        assert "Public read voice messages" in policy_names, "Missing 'Public read voice messages'"
        assert "Authenticated update storage objects" in policy_names, "Missing 'Authenticated update storage objects'"

        print("\n" + "=" * 70)
        print(">>> ALL MIGRATION 02 CHECKS AND POLICY VERIFICATIONS PASSED! <<<")
        print("=" * 70)

    finally:
        con.close()
        print("Database connection closed cleanly.")

if __name__ == "__main__":
    main()
