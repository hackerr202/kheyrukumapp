#!/usr/bin/env python3
"""Environment-backed configuration helper for Kheyrukum maintenance/test scripts."""
import os
import ssl
from urllib.parse import urlparse


def get_db_connection_params() -> dict:
    """Parse SUPABASE_DB_URL from environment and return pg8000 connection kwargs with strict TLS."""
    db_url = os.environ.get("SUPABASE_DB_URL", "").strip()
    if not db_url:
        raise SystemExit(
            "ERROR: SUPABASE_DB_URL environment variable is required "
            "(e.g. postgresql://user:password@host:5432/postgres)."
        )

    parsed = urlparse(db_url)
    if not parsed.hostname or not parsed.username or parsed.password is None:
        raise SystemExit(
            "ERROR: SUPABASE_DB_URL must be a valid PostgreSQL URI with user, password, and host."
        )

    return {
        "user": parsed.username,
        "password": parsed.password,
        "host": parsed.hostname,
        "port": parsed.port or 5432,
        "database": parsed.path.lstrip("/") or "postgres",
        "ssl_context": ssl.create_default_context(),
    }


def get_test_password() -> str:
    """Read test account password from KHEYRUKUM_TEST_PASSWORD environment variable."""
    pwd = os.environ.get("KHEYRUKUM_TEST_PASSWORD", "").strip()
    if not pwd:
        raise SystemExit(
            "ERROR: KHEYRUKUM_TEST_PASSWORD environment variable is required for test scripts."
        )
    return pwd


def get_supabase_url() -> str:
    """Read SUPABASE_URL from environment (or fall back to the public project URL if set)."""
    url = os.environ.get("SUPABASE_URL", "").strip()
    if not url:
        raise SystemExit("ERROR: SUPABASE_URL environment variable is required.")
    return url


def get_supabase_anon_key() -> str:
    """Read SUPABASE_ANON_KEY from environment."""
    key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    if not key:
        raise SystemExit("ERROR: SUPABASE_ANON_KEY environment variable is required.")
    return key
