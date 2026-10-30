import os
import sys
import ssl

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

    # Attempt PostgreSQL connection
    try:
        import pg8000.native
        print("Using pg8000 PostgreSQL driver...")
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        # Connection candidates:
        # 1. Direct connection (IPv6 / default): User is "postgres"
        # 2. Supabase Poolers (IPv4 fallback): User is "postgres.tjhqpzvjzmpyrridtpsj"
        connection_targets = [
            # Direct connection to PostgreSQL host on port 5432
            {
                "label": "Direct PostgreSQL connection (db.tjhqpzvjzmpyrridtpsj.supabase.co:5432)",
                "host": "db.tjhqpzvjzmpyrridtpsj.supabase.co",
                "port": 5432,
                "user": "postgres",
                "timeout": 15,
            },
            # Active project region poolers (eu-west-3)
            {
                "label": "AWS Pooler aws-1-eu-west-3:6543 (Transaction mode)",
                "host": "aws-1-eu-west-3.pooler.supabase.com",
                "port": 6543,
                "user": "postgres.tjhqpzvjzmpyrridtpsj",
                "timeout": 15,
            },
            {
                "label": "AWS Pooler aws-1-eu-west-3:5432 (Session mode)",
                "host": "aws-1-eu-west-3.pooler.supabase.com",
                "port": 5432,
                "user": "postgres.tjhqpzvjzmpyrridtpsj",
                "timeout": 15,
            },
            {
                "label": "AWS Pooler aws-0-eu-west-3:6543",
                "host": "aws-0-eu-west-3.pooler.supabase.com",
                "port": 6543,
                "user": "postgres.tjhqpzvjzmpyrridtpsj",
                "timeout": 15,
            },
            # Dispatch-specified pooler fallback regions
            {
                "label": "AWS Pooler aws-0-eu-central-1:6543",
                "host": "aws-0-eu-central-1.pooler.supabase.com",
                "port": 6543,
                "user": "postgres.tjhqpzvjzmpyrridtpsj",
                "timeout": 15,
            },
            {
                "label": "AWS Pooler aws-0-eu-west-1:6543",
                "host": "aws-0-eu-west-1.pooler.supabase.com",
                "port": 6543,
                "user": "postgres.tjhqpzvjzmpyrridtpsj",
                "timeout": 15,
            },
            {
                "label": "AWS Pooler aws-0-eu-west-2:6543",
                "host": "aws-0-eu-west-2.pooler.supabase.com",
                "port": 6543,
                "user": "postgres.tjhqpzvjzmpyrridtpsj",
                "timeout": 15,
            },
            {
                "label": "AWS Pooler aws-0-me-central-1:6543",
                "host": "aws-0-me-central-1.pooler.supabase.com",
                "port": 6543,
                "user": "postgres.tjhqpzvjzmpyrridtpsj",
                "timeout": 15,
            },
            {
                "label": "AWS Pooler aws-0-ap-south-1:6543",
                "host": "aws-0-ap-south-1.pooler.supabase.com",
                "port": 6543,
                "user": "postgres.tjhqpzvjzmpyrridtpsj",
                "timeout": 15,
            },
            {
                "label": "AWS Pooler aws-0-us-east-1:6543",
                "host": "aws-0-us-east-1.pooler.supabase.com",
                "port": 6543,
                "user": "postgres.tjhqpzvjzmpyrridtpsj",
                "timeout": 15,
            },
        ]

        connected_target = None
        con = None
        for target in connection_targets:
            print(f"Connecting to {target['label']}...", end=" ", flush=True)
            try:
                con = pg8000.native.Connection(
                    user=target["user"],
                    host=target["host"],
                    port=target["port"],
                    database="postgres",
                    password="ustazmuhammedyakut",
                    ssl_context=ctx,
                    timeout=target["timeout"],
                )
                print("SUCCESS!")
                connected_target = target
                break
            except Exception as e:
                print(f"Failed: {e}")

        if not con or not connected_target:
            print("Error: Could not establish database connection across any target.")
            return False

        print(f"Established connection via: {connected_target['label']}")
        print("Executing migration_01_fixes.sql...")

        con.run(sql_content)
        print("SUCCESS: Migration executed successfully against remote database!")

        # Verify applied changes
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
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = run_migration()
    sys.exit(0 if success else 1)
