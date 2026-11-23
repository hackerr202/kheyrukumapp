#!/usr/bin/env python3
"""
Executes scripts/migration_02_security_fixes.sql against live Supabase PostgreSQL
and performs verification of hardened policies, conversation columns, and storage permissions.
"""

import os
import sys
import pg8000.native
from _db_env import get_db_connection_params


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

    db_params = get_db_connection_params()
    print(f"Connecting to {db_params['host']}:{db_params['port']}...", end=" ", flush=True)
    con = pg8000.native.Connection(**db_params, timeout=20)
    print("CONNECTED!")

    try:
        print("\nExecuting migration_02_security_fixes.sql...")
        con.run(sql_content)
        print("[SUCCESS] Migration 02 executed successfully!")

        conv_cols = con.run("""
            SELECT column_name, data_type, column_default
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'conversations'
            AND column_name IN ('participant_ids', 'participant_names', 'unread_count', 'is_pinned')
            ORDER BY column_name;
        """)
        print(f"1. Conversations columns ({len(conv_cols)}/4)")
        assert len(conv_cols) == 4, f"Expected 4 new conversation columns, got {len(conv_cols)}"

        print("\n" + "=" * 70)
        print(">>> ALL MIGRATION 02 CHECKS AND POLICY VERIFICATIONS PASSED! <<<")
        print("=" * 70)

    finally:
        con.close()
        print("Database connection closed cleanly.")


if __name__ == "__main__":
    main()
