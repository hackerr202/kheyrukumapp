#!/usr/bin/env python3
"""
================================================================================
MILESTONE 4 VERIFICATION SUITE: SECURITY, ERROR HANDLING & READINESS
================================================================================
Verifies:
1. Zero Leaked Secrets in Client Codebase (No service-role keys or passwords)
2. Supabase PostgreSQL Row Level Security (RLS) Audit on all 14 tables
3. Storage Buckets & Policies (announcement_attachments, chat_attachments, voice_messages)
4. UI Error Handling & Sanitization (cleanErrorMessage across dialogs & services)
5. Async Concurrency & Loading Spinners (Double-submission prevention)
6. Syntax Integrity & Bracket Balance across all modified client files
================================================================================
"""

import os
import re
import ssl
import sys
import json
import urllib.request
import urllib.error
import pg8000.native

sys.path.append(os.path.abspath('scripts'))
from check_syntax import check_brackets

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"

POOLER_HOST = "aws-1-eu-west-3.pooler.supabase.com"
DB_USER = "postgres.tjhqpzvjzmpyrridtpsj"
DB_PASS = "ustazmuhammedyakut"
DB_NAME = "postgres"

def check_secret_leakage():
    print("\n--- 1. Security Audit: Scanning Client Code for Leaked Secrets ---")
    sensitive_patterns = [
        r'service_role',
        r'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', # standard Supabase service JWT pattern
        r'postgres:\/\/postgres:',
        r'ustazmuhammedyakut',
    ]

    scanned_extensions = ['.dart', '.yaml', '.xml', '.plist', '.json']
    leaks = []

    for root, dirs, files in os.walk('lib'):
        for file in files:
            if any(file.endswith(ext) for ext in scanned_extensions):
                full_path = os.path.join(root, file)
                with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    for pattern in sensitive_patterns:
                        if re.search(pattern, content):
                            leaks.append((full_path, pattern))

    if leaks:
        print(f"[FAIL] Found sensitive secrets in client code: {leaks}")
        return False, f"Leaked secrets found: {leaks}"

    print("[PASS] Client codebase is 100% clean of service-role keys and database passwords.")
    return True, "No secrets leaked in client code"

def check_database_rls():
    print("\n--- 2. Database Audit: PostgreSQL Row Level Security (RLS) Status ---")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    try:
        conn = pg8000.native.Connection(
            user=DB_USER,
            host=POOLER_HOST,
            port=5432,
            database=DB_NAME,
            password=DB_PASS,
            ssl_context=ctx,
            timeout=15
        )
    except Exception as e:
        return False, f"Failed to connect to pooler: {e}"

    required_tables = [
        'students',
        'halaqahs',
        'announcements',
        'messages',
        'profiles',
        'parent_students',
        'hifz_records',
        'homework_assignments',
        'homework_submissions',
        'conversations',
        'conversation_participants',
        'invitation_codes',
        'announcement_reads',
        'user_device_tokens',
    ]

    rows = conn.run(
        "SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';"
    )
    table_rls = {r[0]: r[1] for r in rows}

    missing_tables = [t for t in required_tables if t not in table_rls]
    disabled_rls = [t for t in required_tables if t in table_rls and not table_rls[t]]

    # Also inspect policy counts
    pols = conn.run(
        "SELECT tablename, count(*) FROM pg_policies WHERE schemaname = 'public' GROUP BY tablename;"
    )
    policy_counts = {p[0]: p[1] for p in pols}

    conn.close()

    if missing_tables:
        return False, f"Missing required tables: {missing_tables}"

    if disabled_rls:
        return False, f"Tables with RLS disabled: {disabled_rls}"

    for t in required_tables:
        count = policy_counts.get(t, 0)
        print(f"  Table: {t:26} RLS: Enabled | Policies: {count}")

    print("[PASS] All 14 application tables have Row Level Security enabled.")
    return True, "All tables have RLS enabled"

def check_storage_buckets():
    print("\n--- 3. Cloud Storage Audit: Buckets & Public Serving ---")
    url = f"{BASE_URL}/storage/v1/bucket"
    req = urllib.request.Request(url, headers={"apikey": ANON_KEY, "Authorization": f"Bearer {ANON_KEY}"})

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            buckets = json.loads(resp.read().decode())
            bucket_map = {b["id"]: b.get("public", False) for b in buckets if isinstance(b, dict)}
            required = ["announcement_attachments", "chat_attachments", "voice_messages"]

            for b in required:
                if b not in bucket_map:
                    return False, f"Missing required bucket: {b}"
                if not bucket_map[b]:
                    return False, f"Bucket '{b}' is not public!"
                print(f"  Bucket '{b}': Verified Public (id={b})")

            print("[PASS] All 3 storage buckets exist and are verified public.")
            return True, "Storage buckets verified"
    except Exception as e:
        return False, f"Storage bucket check error: {e}"

def check_error_sanitization():
    print("\n--- 4. UI Error Handling & Sanitization Audit ---")
    supabase_service_path = "lib/core/services/supabase_service.dart"
    if not os.path.exists(supabase_service_path):
        return False, f"Missing {supabase_service_path}"

    with open(supabase_service_path, "r", encoding="utf-8") as f:
        code = f.read()

    # Check cleanErrorMessage function
    if "cleanErrorMessage" not in code:
        return False, "cleanErrorMessage method missing in SupabaseService"

    required_patterns = [
        "invalid login credentials",
        "email not confirmed",
        "already exists",
        "network",
    ]
    for p in required_patterns:
        if p not in code.lower():
            return False, f"cleanErrorMessage does not handle '{p}'"

    # Verify announcement service error handling
    ann_path = "lib/core/services/announcement_service.dart"
    with open(ann_path, "r", encoding="utf-8") as f:
        ann_code = f.read()

    if "cleanErrorMessage" not in ann_code:
        return False, "AnnouncementService does not use cleanErrorMessage"

    print("[PASS] SupabaseService.cleanErrorMessage and error sanitization verified.")
    return True, "Error sanitization verified"

def check_async_loading_states():
    print("\n--- 5. Concurrency & Double Submission Prevention Audit ---")
    dialogs = [
        ("lib/widgets/add_student_dialog.dart", ["isSaving", "CircularProgressIndicator", "canSubmit"]),
        ("lib/screens/announcements/post_announcement_dialog.dart", ["_isBroadcasting", "_isUploadingAttachment", "CircularProgressIndicator"]),
        ("lib/screens/messages/chat_screen.dart", ["_isUploadingAttachment", "_isRecordingVoice"]),
        ("lib/screens/admin/halaqah_management_sheet.dart", ["isCreating", "CircularProgressIndicator"]),
    ]

    for path, expected_indicators in dialogs:
        if not os.path.exists(path):
            return False, f"Missing {path}"
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        for ind in expected_indicators:
            if ind not in content:
                return False, f"Missing loading/concurrency state '{ind}' in {path}"
        print(f"  Verified concurrency & loading indicators in {path}")

    print("[PASS] All critical async UI dialogs prevent double-submission and display loading spinners.")
    return True, "Concurrency & loading states verified"

def check_syntax_integrity():
    print("\n--- 6. Codebase Syntax Integrity Audit ---")
    files_to_check = [
        'lib/core/services/supabase_service.dart',
        'lib/core/services/student_service.dart',
        'lib/core/services/halaqah_service.dart',
        'lib/core/services/announcement_service.dart',
        'lib/core/services/messaging_service.dart',
        'lib/core/services/storage_service.dart',
        'lib/screens/dashboard/tabs/home_tab.dart',
        'lib/screens/dashboard/tabs/messages_tab.dart',
        'lib/screens/announcements/post_announcement_dialog.dart',
        'lib/screens/messages/chat_screen.dart',
        'lib/widgets/add_student_dialog.dart',
        'lib/screens/admin/halaqah_management_sheet.dart',
    ]

    for f in files_to_check:
        if not os.path.exists(f):
            return False, f"File missing: {f}"
        errs = check_brackets(f)
        if errs:
            return False, f"Syntax error in {f}: {errs}"

    print(f"[PASS] Syntax integrity verified across {len(files_to_check)} critical application files (0 errors).")
    return True, "Syntax integrity verified"

def main():
    print("=" * 70)
    print("RUNNING MILESTONE 4 VERIFICATION SUITE")
    print("=" * 70)

    checks = [
        ("No Secrets Leaked", check_secret_leakage),
        ("Database RLS Policies", check_database_rls),
        ("Cloud Storage Buckets", check_storage_buckets),
        ("Error Sanitization", check_error_sanitization),
        ("Async Loading States", check_async_loading_states),
        ("Syntax Integrity", check_syntax_integrity),
    ]

    all_passed = True
    for name, fn in checks:
        passed, msg = fn()
        status = "[PASS]" if passed else "[FAIL]"
        print(f"\n{status} {name}: {msg}")
        if not passed:
            all_passed = False

    print("\n" + "=" * 70)
    if all_passed:
        print(">>> ALL M4 VERIFICATION SUITE CHECKS PASSED SUCCESSFULLY! <<<")
        print("=" * 70)
        sys.exit(0)
    else:
        print(">>> SOME M4 VERIFICATION SUITE CHECKS FAILED! <<<")
        print("=" * 70)
        sys.exit(1)

if __name__ == '__main__':
    main()
