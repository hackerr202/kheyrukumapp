"""Verification suite for scripts/migration_05_security_lockdown.sql.

Usage:
    # Live verification against Supabase PostgreSQL (requires SUPABASE_DB_URL env var):
    python scripts/verify_security_lockdown.py

    # Offline static verification against scripts/migration_05_security_lockdown.sql:
    python scripts/verify_security_lockdown.py --offline
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

from _db_env import get_db_connection_params


PRIVATE_BUCKETS = (
    "payment_receipts",
    "avatars",
    "voice_messages",
    "recitations",
    "voice-feedback",
    "chat_attachments",
    "announcement_attachments",
)

LEGACY_POLICIES_MUST_BE_ABSENT = (
    ("public", "profiles", "Users can update own profile"),
    ("public", "profiles", "Public profiles readable by authenticated"),
    ("public", "invitation_codes", "Anyone can check active invite codes"),
    ("public", "parent_students", "Admins manage parent_students"),
    ("public", "monthly_payments", "Parents update receipt submission"),
    ("storage", "objects", "Public read chat attachments"),
    ("storage", "objects", "Public read voice messages"),
    ("storage", "objects", "Public read avatars"),
    ("storage", "objects", "Authenticated update storage objects"),
)

REQUIRED_SECURITY_DEFINER_FUNCTIONS = (
    "is_active_user",
    "is_superadmin",
    "is_admin",
    "current_user_role",
    "is_teacher",
    "teaches_student",
    "teaches_halaqah",
    "can_view_profile",
    "is_conversation_member",
    "validate_invitation_code",
    "consume_invitation_code",
    "generate_invitation_code",
    "admin_assign_teacher_halaqah",
    "admin_set_user_role",
    "admin_delete_user",
    "create_direct_conversation",
    "guard_profile_privileged_fields",
    "guard_monthly_payment_parent_update",
    "guard_homework_submission_parent_update",
)

AUTH_ONLY_PRIVILEGED_FUNCTIONS = (
    "consume_invitation_code",
    "generate_invitation_code",
    "admin_assign_teacher_halaqah",
    "admin_set_user_role",
    "admin_delete_user",
    "create_direct_conversation",
)

REQUIRED_TRIGGERS = (
    ("profiles", "trg_guard_profile_privileged_fields"),
    ("monthly_payments", "trg_guard_monthly_payment_parent_update"),
    ("homework_submissions", "trg_guard_homework_submission_parent_update"),
)

CORE_RLS_TABLES = (
    ("public", "profiles"),
    ("public", "invitation_codes"),
    ("public", "parent_students"),
    ("public", "halaqahs"),
    ("public", "students"),
    ("public", "monthly_payments"),
    ("public", "conversations"),
    ("public", "conversation_participants"),
    ("public", "messages"),
    ("public", "homework_assignments"),
    ("public", "homework_submissions"),
    ("public", "announcements"),
    ("storage", "objects"),
)

OPTIONAL_RLS_TABLES = (
    ("public", "hifz_records"),
    ("public", "student_attendance"),
    ("public", "weekly_reports"),
    ("public", "absence_requests"),
    ("public", "account_status"),
    ("public", "user_device_tokens"),
    ("public", "announcement_reads"),
    ("public", "notifications"),
)


def _record(failures: list[str], ok: bool, label: str, detail: str = "") -> None:
    status = "PASS" if ok else "FAIL"
    suffix = f" ({detail})" if detail else ""
    print(f"[{status}] {label}{suffix}")
    if not ok:
        failures.append(f"{label}{suffix}")


def _normalize_search_path(config_items: list[str] | None) -> list[str]:
    if not config_items:
        return []
    return [item.replace('"', "").replace("'", "").strip().lower() for item in config_items]


def verify_live_database() -> int:
    try:
        import pg8000
    except ImportError as exc:
        print(f"ERROR: pg8000 is required for live DB verification: {exc}", file=sys.stderr)
        return 2

    params = get_db_connection_params()
    failures: list[str] = []

    with pg8000.connect(**params) as conn:
        cur = conn.cursor()

        # 1. Storage buckets must all be private (public = false).
        cur.execute(
            """
            SELECT id, public
            FROM storage.buckets
            WHERE id = ANY(%s)
            """,
            (list(PRIVATE_BUCKETS),),
        )
        bucket_rows = {row[0]: bool(row[1]) for row in cur.fetchall()}
        for bucket in PRIVATE_BUCKETS:
            if bucket not in bucket_rows:
                _record(failures, False, f"Storage bucket '{bucket}' exists & is private", "bucket missing")
            else:
                is_public = bucket_rows[bucket]
                _record(
                    failures,
                    not is_public,
                    f"Storage bucket '{bucket}' is private",
                    f"public={is_public}",
                )

        # 2. Legacy insecure RLS policies must be removed.
        cur.execute(
            """
            SELECT schemaname, tablename, policyname
            FROM pg_policies
            WHERE schemaname IN ('public', 'storage')
            """
        )
        existing_policies = {(r[0], r[1], r[2]) for r in cur.fetchall()}
        for schema, table, policy in LEGACY_POLICIES_MUST_BE_ABSENT:
            present = (schema, table, policy) in existing_policies
            _record(
                failures,
                not present,
                f"Legacy policy removed: {schema}.{table} -> {policy}",
                "still present" if present else "absent",
            )

        # 3. RLS must be enabled on all sensitive tables.
        cur.execute(
            """
            SELECT n.nspname, c.relname, c.relrowsecurity
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname IN ('public', 'storage') AND c.relkind = 'r'
            """
        )
        rls_map = {(r[0], r[1]): bool(r[2]) for r in cur.fetchall()}
        for schema, table in CORE_RLS_TABLES:
            enabled = rls_map.get((schema, table), False)
            _record(failures, enabled, f"RLS enabled on {schema}.{table}", f"relrowsecurity={enabled}")
        for schema, table in OPTIONAL_RLS_TABLES:
            if (schema, table) not in rls_map:
                print(f"[SKIP] RLS check on optional table {schema}.{table} (table not present)")
            else:
                enabled = rls_map[(schema, table)]
                _record(failures, enabled, f"RLS enabled on optional table {schema}.{table}", f"relrowsecurity={enabled}")

        # 4. Inspect active policies on invitation_codes, monthly_payments, and storage.objects.
        cur.execute(
            """
            SELECT schemaname, tablename, policyname, roles, cmd, COALESCE(qual, ''), COALESCE(with_check, '')
            FROM pg_policies
            WHERE schemaname IN ('public', 'storage')
            """
        )
        all_policy_rows = cur.fetchall()

        invite_anon_policies = [
            row[2]
            for row in all_policy_rows
            if row[0] == "public" and row[1] == "invitation_codes" and "anon" in (row[3] or [])
        ]
        _record(
            failures,
            len(invite_anon_policies) == 0,
            "No anon policy on public.invitation_codes",
            f"anon policies={invite_anon_policies}" if invite_anon_policies else "0 anon policies",
        )

        payment_admin_leak = [
            row[2]
            for row in all_policy_rows
            if row[0] == "public"
            and row[1] == "monthly_payments"
            and ("is_admin" in row[5].lower() or "is_admin" in row[6].lower())
        ]
        _record(
            failures,
            len(payment_admin_leak) == 0,
            "Standard admins excluded from monthly_payments policies",
            f"policies referencing is_admin={payment_admin_leak}" if payment_admin_leak else "superadmin/parent only",
        )

        payment_superadmin_policies = [
            row[2]
            for row in all_policy_rows
            if row[0] == "public"
            and row[1] == "monthly_payments"
            and ("is_superadmin" in row[5].lower() or "is_superadmin" in row[6].lower())
        ]
        _record(
            failures,
            len(payment_superadmin_policies) > 0,
            "Superadmin policy present on monthly_payments",
            f"policies={payment_superadmin_policies}",
        )

        storage_public_or_anon = [
            row[2]
            for row in all_policy_rows
            if row[0] == "storage"
            and row[1] == "objects"
            and (
                "anon" in (row[3] or [])
                or row[5].strip().lower() == "true"
                or row[6].strip().lower() == "true"
            )
        ]
        _record(
            failures,
            len(storage_public_or_anon) == 0,
            "No anon or blanket TRUE policies on storage.objects",
            f"violations={storage_public_or_anon}" if storage_public_or_anon else "all scoped",
        )

        # 5. Inspect SECURITY DEFINER functions, search_path, and PUBLIC/anon EXECUTE grants.
        cur.execute(
            """
            SELECT
                p.oid,
                p.proname,
                p.prosecdef,
                p.proconfig,
                COALESCE(p.proacl::text, ''),
                has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
                has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_exec
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname = ANY(%s)
            """,
            (list(REQUIRED_SECURITY_DEFINER_FUNCTIONS),),
        )
        fn_rows = cur.fetchall()
        fn_by_name: dict[str, list[tuple]] = {}
        for row in fn_rows:
            fn_by_name.setdefault(row[1], []).append(row)

        for fn_name in REQUIRED_SECURITY_DEFINER_FUNCTIONS:
            matches = fn_by_name.get(fn_name, [])
            if not matches:
                _record(failures, False, f"Function public.{fn_name} exists & hardened", "missing")
                continue

            for _oid, _name, prosecdef, proconfig, proacl, anon_exec, _auth_exec in matches:
                normalized_cfg = _normalize_search_path(proconfig)
                has_search_path = any(
                    cfg == "search_path=public, pg_temp" or cfg == "search_path=public,pg_temp"
                    for cfg in normalized_cfg
                )
                has_public_grant = "=x/" in proacl.lower()
                is_priv_auth_only = fn_name in AUTH_ONLY_PRIVILEGED_FUNCTIONS
                anon_ok = True if not is_priv_auth_only else (not bool(anon_exec))
                ok = bool(prosecdef) and has_search_path and (not has_public_grant) and anon_ok
                _record(
                    failures,
                    ok,
                    f"Function public.{fn_name} SECURITY DEFINER + search_path + grants",
                    f"secdef={prosecdef}, config={proconfig}, public_grant={has_public_grant}, anon_exec={anon_exec}",
                )

        # 6. Verify active triggers on profiles, monthly_payments, homework_submissions.
        cur.execute(
            """
            SELECT c.relname, t.tgname, t.tgenabled
            FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND NOT t.tgisinternal
            """
        )
        triggers = {(r[0], r[1]): r[2] for r in cur.fetchall()}
        for table, trg_name in REQUIRED_TRIGGERS:
            state = triggers.get((table, trg_name))
            ok = state is not None and state != "D"
            _record(
                failures,
                ok,
                f"Trigger {trg_name} active on public.{table}",
                f"tgenabled={state}" if state is not None else "missing",
            )

    print("\nSummary:", "ALL CHECKS PASSED" if not failures else f"{len(failures)} CHECK(S) FAILED")
    return 0 if not failures else 1


def verify_offline_sql() -> int:
    sql_path = Path(__file__).resolve().parent / "migration_05_security_lockdown.sql"
    if not sql_path.is_file():
        print(f"ERROR: Missing SQL migration at {sql_path}", file=sys.stderr)
        return 2

    sql_text = sql_path.read_text(encoding="utf-8")
    failures: list[str] = []

    for bucket in PRIVATE_BUCKETS:
        ok = bool(re.search(rf"\(\s*'{re.escape(bucket)}'\s*,\s*'{re.escape(bucket)}'\s*,\s*false\s*\)|public\s*=\s*false", sql_text, re.IGNORECASE))
        bucket_listed = f"'{bucket}'" in sql_text and "public = false" in sql_text.lower()
        _record(failures, ok and bucket_listed, f"SQL sets bucket '{bucket}' private")

    for fn_name in REQUIRED_SECURITY_DEFINER_FUNCTIONS:
        fn_re = re.compile(
            rf"CREATE\s+OR\s+REPLACE\s+FUNCTION\s+public\.{re.escape(fn_name)}\b(.*?)(?=\nCREATE\s+OR\s+REPLACE\s+FUNCTION|\nDROP\s+TRIGGER|\Z)",
            re.IGNORECASE | re.DOTALL,
        )
        m = fn_re.search(sql_text)
        has_fn = m is not None
        body = m.group(0) if m else ""
        has_secdef = "SECURITY DEFINER" in body.upper()
        has_search_path = bool(re.search(r"SET\s+search_path\s*=\s*public\s*,\s*pg_temp", body, re.IGNORECASE))
        _record(
            failures,
            has_fn and has_secdef and has_search_path,
            f"SQL defines public.{fn_name} with SECURITY DEFINER + search_path",
            f"fn={has_fn}, secdef={has_secdef}, search_path={has_search_path}",
        )

    for table, trg_name in REQUIRED_TRIGGERS:
        has_trg = bool(
            re.search(
                rf"CREATE\s+TRIGGER\s+{re.escape(trg_name)}.*?ON\s+public\.{re.escape(table)}\b",
                sql_text,
                re.IGNORECASE | re.DOTALL,
            )
        )
        _record(failures, has_trg, f"SQL creates trigger {trg_name} on public.{table}")

    for _schema, _table, policy in LEGACY_POLICIES_MUST_BE_ABSENT:
        has_drop = f'DROP POLICY IF EXISTS "{policy}"' in sql_text
        _record(failures, has_drop, f"SQL drops legacy policy '{policy}'")

    for _schema, table in OPTIONAL_RLS_TABLES:
        guarded = bool(
            re.search(
                rf"IF\s+to_regclass\(\s*'public\.{re.escape(table)}'\s*\)\s+IS\s+NOT\s+NULL\s+THEN\s+EXECUTE\s+\$ddl\$.*?ALTER\s+TABLE\s+public\.{re.escape(table)}\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY",
                sql_text,
                re.IGNORECASE | re.DOTALL,
            )
        )
        _record(failures, guarded, f"SQL guards optional RLS table public.{table} with to_regclass")

    for forbidden in ("postgresql://", "CERT_NONE", "admin@" + "kheyrukum.com"):
        absent = forbidden not in sql_text
        _record(failures, absent, f"SQL contains no hardcoded '{forbidden}'")

    print("\nOffline SQL Summary:", "ALL CHECKS PASSED" if not failures else f"{len(failures)} CHECK(S) FAILED")
    return 0 if not failures else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify Phase 1B Supabase security lockdown.")
    parser.add_argument(
        "--offline",
        action="store_true",
        help="Validate scripts/migration_05_security_lockdown.sql statically without connecting to Supabase.",
    )
    args = parser.parse_args()
    if args.offline:
        return verify_offline_sql()
    return verify_live_database()


if __name__ == "__main__":
    raise SystemExit(main())
