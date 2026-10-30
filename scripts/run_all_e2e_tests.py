#!/usr/bin/env python3
"""
================================================================================
KHEYRUKUM MOBILE APP: MASTER UNIFIED E2E TEST RUNNER
================================================================================
Executes the comprehensive 4-Tier test suite across live cloud backend (Supabase)
and Flutter mobile codebase:

Tier 1: Feature Verification
  - scripts/verify_m1.py            (Backend & Database Architect)
  - scripts/verify_m2.py            (UI/UX & Frontend Layout)
  - scripts/verify_m3.py            (Native Media, Storage & Audio)
  - scripts/verify_m4.py            (Security, QA & Deployment Readiness)
  - scripts/check_syntax.py         (Syntax Integrity & Bracket Balance)

Tier 2 & 3: Boundary, Cross-Feature & Adversarial Checks
  - scripts/adversarial_challenge_m3.py (Storage Upload, CDN GET & Zero Clipboard)
  - scripts/adversarial_challenge_m4.py (RLS Attack Vectors, Role Separation & Upsert)

Tier 4: Real-World Acceptance Workloads
  - scripts/e2e_acceptance_checklist.py  (4-Point Acceptance Verification Checklist)
  - scripts/challenger_stress_harness.py (Adversarial Empirical Stress Harness)

================================================================================
"""

import os
import sys
import time
import subprocess

# Ensure UTF-8 output on Windows
if sys.platform.startswith("win"):
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

TIERS = [
    {
        "tier": "Tier 1: Feature Verification & Unit Contracts",
        "description": "Verifies core milestone implementations, schema alignments, and code integrity",
        "tests": [
            {
                "id": "T1-M1",
                "name": "M1 Backend & Database Verification",
                "script": "scripts/verify_m1.py",
                "features": [1, 2, 3, 4, 5],
            },
            {
                "id": "T1-M2",
                "name": "M2 UI/UX & Layout Verification",
                "script": "scripts/verify_m2.py",
                "features": [6, 7, 8, 9],
            },
            {
                "id": "T1-M3",
                "name": "M3 Native Media & Audio Verification",
                "script": "scripts/verify_m3.py",
                "features": [10, 11, 12, 13],
            },
            {
                "id": "T1-M4",
                "name": "M4 Security & Readiness Verification",
                "script": "scripts/verify_m4.py",
                "features": [14, 15, 16],
            },
            {
                "id": "T1-SYN",
                "name": "Syntax & Bracket Balance Verification",
                "script": "scripts/check_syntax.py",
                "features": [1, 2, 6, 8, 9, 15],
            },
        ],
    },
    {
        "tier": "Tier 2 & 3: Boundary, Cross-Feature & Adversarial Checks",
        "description": "Attacks and stresses storage limits, RLS boundaries, and role privilege separation",
        "tests": [
            {
                "id": "T2-M3-ADV",
                "name": "M3 Adversarial Storage & Media Challenge",
                "script": "scripts/adversarial_challenge_m3.py",
                "features": [4, 11, 12, 13],
            },
            {
                "id": "T3-M4-ADV",
                "name": "M4 Live RLS Penetration & Privilege Challenge",
                "script": "scripts/adversarial_challenge_m4.py",
                "features": [1, 2, 3, 4, 14],
            },
        ],
    },
    {
        "tier": "Tier 4: Real-World Acceptance Workloads",
        "description": "Empirical end-to-end client scenarios against live Supabase backend",
        "tests": [
            {
                "id": "T4-ACC-CHK",
                "name": "4-Point Mandatory Acceptance Checklist",
                "script": "scripts/e2e_acceptance_checklist.py",
                "features": [2, 3, 11, 12, 13, 17],
            },
            {
                "id": "T4-STR-HAR",
                "name": "Challenger Stress & Geometry Harness",
                "script": "scripts/challenger_stress_harness.py",
                "features": [1, 2, 3, 5, 6, 11, 12, 13, 17],
            },
        ],
    },
]

FEATURE_INVENTORY = {
    1: "Announcements Schema Fix (attachment_name & attachment_url, PGRST204 fix)",
    2: "Student Persistence on Reinstall (Supabase table CRUD, parent linkage)",
    3: "Halaqah (Circle) Creation Flow (schema payload, RLS, immediate UI update)",
    4: "Supabase Storage Buckets Setup (announcements, chats, voice with RLS)",
    5: "Messages Schema & Persistence (attachment_name/url, audio_duration)",
    6: "Fix Hidden '+ New Chat' Button (FAB positioning & clearance above MeniscusNavBar)",
    7: "Redesign Chats Empty State & List (modern CTA, role badges, online status)",
    8: "Redesign Home Page Announcements (>=3 items carousel, admin stats card)",
    9: "Fix Dialog Contrast & Text Visibility (dark mode poppinsTextTheme, dialogTheme)",
    10: "Native Permissions Configuration (AndroidManifest, Info.plist, pubspec)",
    11: "Announcement Device File Upload (file_picker, storage upload, zero clipboard)",
    12: "Chat Attachment Device Upload (gallery/docs, chat_attachments bucket)",
    13: "Voice Message Recording & Playback (record AAC .m4a, audioplayers stream)",
    14: "Security & RLS Policy Enforcement (all 14 tables, zero leaked secrets)",
    15: "Global Error Handling & UI Sanitization (cleanErrorMessage in UI/services)",
    16: "Concurrency & Loading Spinners (async loading states, double-submit prevention)",
    17: "End-to-End Acceptance Verification (4-point verification checklist passed)",
    18: "E2E Test Suite Creation (Master unified runner, 4 tiers automated execution)",
}

def run_test_suite(test_item):
    script_path = os.path.join(PROJECT_ROOT, test_item["script"])
    if not os.path.exists(script_path):
        return {
            "success": False,
            "duration": 0.0,
            "output": f"Script not found: {script_path}",
            "returncode": -1,
        }

    start_time = time.time()
    try:
        proc = subprocess.run(
            [sys.executable, "-u", script_path],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=240,
            encoding="utf-8",
            errors="replace",
        )
        duration = time.time() - start_time
        success = (proc.returncode == 0)
        output = proc.stdout + ("\n--- STDERR ---\n" + proc.stderr if proc.stderr.strip() else "")
        return {
            "success": success,
            "duration": duration,
            "output": output,
            "returncode": proc.returncode,
        }
    except subprocess.TimeoutExpired as e:
        duration = time.time() - start_time
        return {
            "success": False,
            "duration": duration,
            "output": f"Test timed out after 180s: {e}",
            "returncode": -2,
        }
    except Exception as e:
        duration = time.time() - start_time
        return {
            "success": False,
            "duration": duration,
            "output": f"Unexpected execution error: {e}",
            "returncode": -3,
        }

def main():
    print("=" * 80)
    print("      KHEYRUKUM MOBILE APP - MASTER UNIFIED E2E TEST RUNNER")
    print("=" * 80)
    print(f"Timestamp    : {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}")
    print(f"Project Root : {PROJECT_ROOT}")
    print(f"Python Exec  : {sys.executable}")
    print(f"Cloud Target : Live Supabase Backend (tjhqpzvjzmpyrridtpsj)")
    print("=" * 80)

    overall_start = time.time()
    suite_results = []
    feature_coverage = {f_num: set() for f_num in FEATURE_INVENTORY.keys()}
    # Feature 18 is this runner itself
    feature_coverage[18].add("scripts/run_all_e2e_tests.py")

    all_suites_passed = True

    for tier_info in TIERS:
        tier_title = tier_info["tier"]
        tier_desc = tier_info["description"]
        print(f"\n>>> {tier_title.upper()}")
        print(f"    {tier_desc}")
        print("-" * 80)

        for test in tier_info["tests"]:
            test_id = test["id"]
            test_name = test["name"]
            script = test["script"]
            print(f"  [{test_id}] Running {test_name} ({script})...", end="", flush=True)

            res = run_test_suite(test)
            suite_results.append({
                "tier": tier_title,
                "id": test_id,
                "name": test_name,
                "script": script,
                "features": test["features"],
                "success": res["success"],
                "duration": res["duration"],
                "returncode": res["returncode"],
                "output": res["output"],
            })

            if res["success"]:
                print(f" \033[92m[PASS]\033[0m ({res['duration']:.2f}s)")
                for f_id in test["features"]:
                    feature_coverage[f_id].add(test_id)
            else:
                print(f" \033[91m[FAIL]\033[0m (exit={res['returncode']}, {res['duration']:.2f}s)")
                all_suites_passed = False
                print(f"\n--- FAILED TEST OUTPUT: {test_name} ---")
                lines = res["output"].strip().splitlines()
                # Print last 25 lines of failure output
                for l in lines[-25:]:
                    print(f"    {l}")
                print("-" * 80)

    total_duration = time.time() - overall_start

    # ==========================================================================
    # DETAILED TEST SUITE SUMMARY
    # ==========================================================================
    print("\n" + "=" * 80)
    print("                       TEST SUITE EXECUTION SUMMARY")
    print("=" * 80)
    print(f"{'ID':<12} | {'Suite Name':<38} | {'Status':<8} | {'Duration':<8} | {'Exit'}")
    print("-" * 80)
    for r in suite_results:
        status_str = "PASS" if r["success"] else "FAIL"
        print(f"{r['id']:<12} | {r['name'][:38]:<38} | {status_str:<8} | {r['duration']:>6.2f}s | {r['returncode']}")
    print("-" * 80)

    total_count = len(suite_results)
    passed_count = sum(1 for r in suite_results if r["success"])
    failed_count = total_count - passed_count
    pass_rate = (passed_count / total_count * 100) if total_count > 0 else 0

    print(f"Total Suites : {total_count}")
    print(f"Passed       : {passed_count}")
    print(f"Failed       : {failed_count}")
    print(f"Pass Rate    : {pass_rate:.1f}%")
    print(f"Total Time   : {total_duration:.2f}s")

    # ==========================================================================
    # 18-FEATURE COVERAGE MATRIX
    # ==========================================================================
    print("\n" + "=" * 80)
    print("             PROJECT.MD FEATURE INVENTORY COVERAGE MATRIX (18/18)")
    print("=" * 80)
    print(f"{'#':<3} | {'Feature Description':<50} | {'Verifying Suites'}")
    print("-" * 80)
    all_features_covered = True
    for f_num, desc in FEATURE_INVENTORY.items():
        verifiers = sorted(list(feature_coverage[f_num]))
        cov_str = ", ".join(verifiers) if verifiers else "NONE"
        status_flag = "[OK]" if verifiers else "[UNTESTED]"
        if not verifiers:
            all_features_covered = False
        print(f"{f_num:<3} | {desc[:50]:<50} | {status_flag} {cov_str}")
    print("-" * 80)

    # ==========================================================================
    # FINAL VERDICT
    # ==========================================================================
    print("\n" + "=" * 80)
    if all_suites_passed and all_features_covered:
        print(">>> FINAL VERDICT: 100% PASS - ALL 18 FEATURES PRODUCTION READY <<<")
        print("=" * 80)
        sys.exit(0)
    else:
        print(">>> FINAL VERDICT: TEST SUITE FAILED OR INCOMPLETE COVERAGE <<<")
        print("=" * 80)
        sys.exit(1)

if __name__ == "__main__":
    main()
