import os
import sys
import traceback
from _db_env import get_db_connection_params


def run_migration():
    print("=" * 60)
    print("KHEYRUKUM SUPABASE MIGRATION RUNNER")
    print("=" * 60)

    sql_path = os.path.join(os.path.dirname(__file__), "migration_01_fixes.sql")
    if not os.path.exists(sql_path):
        print(f"Error: Migration file not found at {sql_path}")
        return False

    with open(sql_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    print(f"Loaded migration SQL ({len(sql_content)} bytes)")

    try:
        import pg8000.native
        db_params = get_db_connection_params()
        print(f"Connecting to {db_params['host']}:{db_params['port']} with TLS verification...")
        con = pg8000.native.Connection(**db_params, timeout=15)
        print("SUCCESS!")

        print("Executing migration_01_fixes.sql...")
        con.run(sql_content)
        print("SUCCESS: Migration executed successfully against remote database!")

        print("\nVerifying schema changes directly in database:")
        announcements_cols = con.run("""
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'announcements'
            AND column_name IN ('attachment_name', 'attachment_url');
        """)
        print("  Announcements columns:", announcements_cols)

        halaqahs_cols = con.run("""
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'halaqahs'
            AND column_name = 'schedule';
        """)
        print("  Halaqahs columns:", halaqahs_cols)

        buckets = con.run("""
            SELECT id, name, public
            FROM storage.buckets
            WHERE id IN ('announcement_attachments', 'chat_attachments', 'voice_messages');
        """)
        print("  Storage buckets:", buckets)

        con.close()
        print("\nDatabase connection closed cleanly.")
        return True

    except Exception as e:
        print(f"Migration execution failed with error: {e}")
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = run_migration()
    sys.exit(0 if success else 1)
