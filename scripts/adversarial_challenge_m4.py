#!/usr/bin/env python3
"""
================================================================================
ADVERSARIAL SECURITY & RLS CHALLENGE TEST HARNESS (M4)
================================================================================
Empirically attacks, probes, and stress-tests:
1. Live Supabase DB RLS Attack Scenarios:
   - Authenticated non-admin (Parent role) attempts:
     a) Unauthorized DELETE / UPDATE on `announcements` -> REJECTED by RLS
     b) Unauthorized INSERT / DELETE on `halaqahs` -> REJECTED by RLS
     c) Unauthorized INSERT / DELETE on `students` -> REJECTED by RLS
     d) Unauthorized access to other parents' records in `parent_students` -> REJECTED by RLS
     e) Valid Admin CAN create announcements, halaqahs, and enroll students -> SUCCEEDS
     f) Valid Teacher CAN enroll students and update assigned halaqah -> SUCCEEDS
2. Storage Bucket Penetration:
   - Unauthenticated public GET on:
     - announcement_attachments
     - chat_attachments
     - voice_messages
     -> All return HTTP 200 with byte-perfect payload.
   - Unauthenticated write on all 3 buckets:
     -> Rejected (HTTP 401/403).
   - Authenticated write and update (upsert: true):
     -> Succeeds (HTTP 200/201).
================================================================================
"""

import os
import ssl
import sys
import json
import time
import urllib.request
import urllib.error
import pg8000.native

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"

POOLER_HOST = "aws-1-eu-west-3.pooler.supabase.com"
DB_USER = "postgres.tjhqpzvjzmpyrridtpsj"
DB_PASS = "ustazmuhammedyakut"
DB_NAME = "postgres"

ADMIN_EMAIL = "challenger_test_m1@kheyrukum.com"
PARENT_EMAIL = "challenger_parent_m4@kheyrukum.com"
TEACHER_EMAIL = "challenger_teacher_m4@kheyrukum.com"
TEST_PASSWORD = "TestPassword123!"

def get_db_connection():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return pg8000.native.Connection(
        user=DB_USER,
        host=POOLER_HOST,
        port=5432,
        database=DB_NAME,
        password=DB_PASS,
        ssl_context=ctx,
        timeout=15
    )

def setup_user_and_profile(email, password, role, full_name):
    """Ensures user exists in auth.users, auth.identities, and has the requested role in public.profiles, returning user_id and JWT token."""
    # 1. Try signing up via auth API (ignore error if user already exists)
    signup_url = f"{BASE_URL}/auth/v1/signup"
    req_signup = urllib.request.Request(
        signup_url,
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
        data=json.dumps({"email": email, "password": password}).encode()
    )
    try:
        urllib.request.urlopen(req_signup, timeout=10)
    except urllib.error.HTTPError:
        pass # Already exists or rate limited

    # 2. Connect via PostgreSQL to confirm email and set profile role
    conn = get_db_connection()
    try:
        users = conn.run(f"SELECT id FROM auth.users WHERE email = '{email}'")
        if not users:
            res = conn.run(
                f"INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, confirmation_token, recovery_token, email_change_token_new, email_change, email_change_token_current, phone_change, phone_change_token, reauthentication_token, created_at, updated_at) "
                f"VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '{email}', "
                f"extensions.crypt('{password}', extensions.gen_salt('bf')), NOW(), '{{\"provider\":\"email\",\"providers\":[\"email\"]}}', '{{\"sub\":\"{email}\",\"email\":\"{email}\"}}', '', '', '', '', '', '', '', '', NOW(), NOW()) "
                f"RETURNING id;"
            )
            user_id = str(res[0][0])
        else:
            user_id = str(users[0][0])
            conn.run(
                f"UPDATE auth.users SET email_confirmed_at = NOW(), "
                f"encrypted_password = extensions.crypt('{password}', extensions.gen_salt('bf')), "
                f"confirmation_token = COALESCE(confirmation_token, ''), "
                f"recovery_token = COALESCE(recovery_token, ''), "
                f"email_change_token_new = COALESCE(email_change_token_new, ''), "
                f"email_change = COALESCE(email_change, ''), "
                f"email_change_token_current = COALESCE(email_change_token_current, ''), "
                f"phone_change = COALESCE(phone_change, ''), "
                f"phone_change_token = COALESCE(phone_change_token, ''), "
                f"reauthentication_token = COALESCE(reauthentication_token, '') "
                f"WHERE id = '{user_id}'"
            )

        # Ensure identity exists in auth.identities for GoTrue login
        conn.run(
            f"INSERT INTO auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at) "
            f"VALUES (gen_random_uuid(), '{user_id}', '{user_id}', jsonb_build_object('sub', '{user_id}', 'email', '{email}'), 'email', NOW(), NOW(), NOW()) "
            f"ON CONFLICT (provider_id, provider) DO UPDATE SET identity_data = jsonb_build_object('sub', '{user_id}', 'email', '{email}');"
        )

        # Upsert profile with exact requested role
        conn.run(
            f"INSERT INTO public.profiles (id, role, full_name, email) "
            f"VALUES ('{user_id}', '{role}'::user_role, '{full_name}', '{email}') "
            f"ON CONFLICT (id) DO UPDATE SET role = '{role}'::user_role, full_name = '{full_name}', email = '{email}';"
        )
    finally:
        conn.close()

    # 3. Log in to get standard JWT token
    login_url = f"{BASE_URL}/auth/v1/token?grant_type=password"
    req_login = urllib.request.Request(
        login_url,
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
        data=json.dumps({"email": email, "password": password}).encode()
    )
    with urllib.request.urlopen(req_login, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        token = data["access_token"]
        return user_id, token

def rest_request(method, path, token=None, data=None, prefer="return=representation"):
    url = f"{BASE_URL}/rest/v1/{path}"
    headers = {
        "apikey": ANON_KEY,
        "Content-Type": "application/json",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if prefer:
        headers["Prefer"] = prefer

    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=25) as resp:
                content = resp.read().decode()
                return resp.status, json.loads(content) if content else None
        except urllib.error.HTTPError as e:
            err_content = e.read().decode()
            try:
                err_json = json.loads(err_content)
            except Exception:
                err_json = {"raw": err_content}
            return e.code, err_json
        except (urllib.error.URLError, TimeoutError, Exception) as e:
            if attempt == 2:
                raise
            time.sleep(1.5)

def storage_request(method, path, token=None, data=None, content_type="application/octet-stream", upsert=False):
    url = f"{BASE_URL}/storage/v1/{path}"
    headers = {}
    if token:
        headers["apikey"] = ANON_KEY
        headers["Authorization"] = f"Bearer {token}"
    if content_type:
        headers["Content-Type"] = content_type
    if upsert:
        headers["x-upsert"] = "true"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=25) as resp:
                return resp.status, resp.read()
        except urllib.error.HTTPError as e:
            return e.code, e.read()
        except (urllib.error.URLError, TimeoutError, Exception) as e:
            if attempt == 2:
                raise
            time.sleep(1.5)

def public_get_with_retry(url, timeout=25):
    req = urllib.request.Request(url, method="GET")
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.status, resp.read()
        except (urllib.error.URLError, TimeoutError, Exception) as e:
            if attempt == 2:
                raise
            time.sleep(1.5)

def run_tests():
    print("=" * 80)
    print("STARTING EMPIRICAL ADVERSARIAL SECURITY & RLS CHALLENGE")
    print("=" * 80)

    # 1. Provision / Refresh Roles
    print("\n--- Provisioning Test Principals (Admin, Parent, Teacher) ---")
    admin_id, admin_token = setup_user_and_profile(ADMIN_EMAIL, TEST_PASSWORD, "admin", "Challenger Admin")
    print(f"Admin Principal  : ID={admin_id} (Role=admin, Token Length={len(admin_token)})")

    parent_id, parent_token = setup_user_and_profile(PARENT_EMAIL, TEST_PASSWORD, "parent", "Challenger Parent")
    print(f"Parent Principal : ID={parent_id} (Role=parent, Token Length={len(parent_token)})")

    teacher_id, teacher_token = setup_user_and_profile(TEACHER_EMAIL, TEST_PASSWORD, "teacher", "Challenger Teacher")
    print(f"Teacher Principal: ID={teacher_id} (Role=teacher, Token Length={len(teacher_token)})")

    results = {}

    # ==========================================================================
    # ATTACK 1: Announcements Unauthorized DELETE / UPDATE by Non-Admin
    # ==========================================================================
    print("\n" + "=" * 60)
    print("ATTACK 1: Unauthorized Announcements Modification by Parent")
    print("=" * 60)

    # Admin creates a target announcement
    ann_payload = {
        "title": f"Target Announcement {int(time.time())}",
        "content": "Official announcement to be protected against unauthorized edits.",
        "author_name": "Center Admin",
        "target_audience": "all",
    }
    status, res = rest_request("POST", "announcements", token=admin_token, data=ann_payload)
    assert status in (200, 201), f"Admin failed to create target announcement: {res}"
    target_ann_id = res[0]["id"]
    print(f"Admin created target announcement: {target_ann_id}")

    # Parent attempts unauthorized UPDATE
    print("Attempting unauthorized UPDATE on announcement as Parent...")
    hack_payload = {"title": "HAXORED ANNOUNCEMENT TITLE", "content": "Tampered content"}
    status_up, res_up = rest_request("PATCH", f"announcements?id=eq.{target_ann_id}", token=parent_token, data=hack_payload)
    print(f"Parent UPDATE Response: status={status_up}, body={res_up}")
    assert status_up in (401, 403) or (status_up == 200 and len(res_up) == 0), f"RLS failed to block announcement UPDATE: {res_up}"

    # Verify content in DB remained uncompromised
    status_chk, res_chk = rest_request("GET", f"announcements?id=eq.{target_ann_id}", token=admin_token)
    assert res_chk[0]["title"] == ann_payload["title"], "Security Breach: Announcement title was tampered by parent!"
    print("[PASS] Unauthorized UPDATE blocked: Announcement title unchanged.")

    # Parent attempts unauthorized DELETE
    print("Attempting unauthorized DELETE on announcement as Parent...")
    status_del, res_del = rest_request("DELETE", f"announcements?id=eq.{target_ann_id}", token=parent_token)
    print(f"Parent DELETE Response: status={status_del}, body={res_del}")
    assert status_del in (401, 403) or (status_del == 200 and len(res_del) == 0), f"RLS failed to block announcement DELETE: {res_del}"

    # Verify announcement still exists
    status_chk2, res_chk2 = rest_request("GET", f"announcements?id=eq.{target_ann_id}", token=admin_token)
    assert len(res_chk2) == 1, "Security Breach: Announcement was deleted by parent!"
    print("[PASS] Unauthorized DELETE blocked: Announcement persists.")

    # Cleanup announcement by Admin
    rest_request("DELETE", f"announcements?id=eq.{target_ann_id}", token=admin_token)
    results["Attack 1: Unauthorized Announcements UPDATE/DELETE"] = True

    # ==========================================================================
    # ATTACK 2: Halaqahs Unauthorized INSERT / DELETE by Non-Admin
    # ==========================================================================
    print("\n" + "=" * 60)
    print("ATTACK 2: Unauthorized Halaqah INSERT / DELETE by Parent")
    print("=" * 60)

    # Parent attempts unauthorized INSERT into halaqahs
    print("Attempting unauthorized INSERT into halaqahs as Parent...")
    hack_hal = {
        "name": "Rogue Halaqah by Parent",
        "description": "Unauthorized circle creation",
    }
    status_hal_in, res_hal_in = rest_request("POST", "halaqahs", token=parent_token, data=hack_hal)
    print(f"Parent Halaqah INSERT Response: status={status_hal_in}, body={res_hal_in}")
    assert status_hal_in in (401, 403) or (isinstance(res_hal_in, dict) and res_hal_in.get("code") == "42501"), \
        f"Security Breach: Parent was able to insert a halaqah: {res_hal_in}"
    print("[PASS] Unauthorized Halaqah INSERT blocked by RLS (42501/403).")

    # Admin creates a valid halaqah
    admin_hal = {"name": f"Protected Circle {int(time.time())}", "description": "Admin circle"}
    status_adm_hal, res_adm_hal = rest_request("POST", "halaqahs", token=admin_token, data=admin_hal)
    assert status_adm_hal in (200, 201), f"Admin failed to create halaqah: {res_adm_hal}"
    target_hal_id = res_adm_hal[0]["id"]
    print(f"Admin created halaqah: {target_hal_id}")

    # Parent attempts unauthorized DELETE of halaqah
    print("Attempting unauthorized DELETE on halaqah as Parent...")
    status_hal_del, res_hal_del = rest_request("DELETE", f"halaqahs?id=eq.{target_hal_id}", token=parent_token)
    print(f"Parent Halaqah DELETE Response: status={status_hal_del}, body={res_hal_del}")
    assert status_hal_del in (401, 403) or (status_hal_del == 200 and len(res_hal_del) == 0), \
        f"Security Breach: Parent was able to delete halaqah: {res_hal_del}"

    # Verify halaqah still exists
    status_chk_hal, res_chk_hal = rest_request("GET", f"halaqahs?id=eq.{target_hal_id}", token=admin_token)
    assert len(res_chk_hal) == 1, "Security Breach: Halaqah was deleted by parent!"
    print("[PASS] Unauthorized Halaqah DELETE blocked: Halaqah persists.")

    # Cleanup halaqah by Admin
    rest_request("DELETE", f"halaqahs?id=eq.{target_hal_id}", token=admin_token)
    results["Attack 2: Unauthorized Halaqahs INSERT/DELETE"] = True

    # ==========================================================================
    # ATTACK 3: Students Unauthorized INSERT / DELETE by Non-Admin / Non-Teacher
    # ==========================================================================
    print("\n" + "=" * 60)
    print("ATTACK 3: Unauthorized Students INSERT / DELETE by Parent")
    print("=" * 60)

    # Parent attempts unauthorized INSERT into students
    print("Attempting unauthorized INSERT into students as Parent...")
    hack_stu = {
        "full_name": "Rogue Student Injected by Parent",
        "current_juz": 1,
    }
    status_stu_in, res_stu_in = rest_request("POST", "students", token=parent_token, data=hack_stu)
    print(f"Parent Student INSERT Response: status={status_stu_in}, body={res_stu_in}")
    assert status_stu_in in (401, 403) or (isinstance(res_stu_in, dict) and res_stu_in.get("code") == "42501"), \
        f"Security Breach: Parent was able to insert student directly: {res_stu_in}"
    print("[PASS] Unauthorized Students INSERT blocked by RLS (42501/403).")

    # Admin creates a valid student
    admin_stu = {"full_name": f"Admin Enrolled Student {int(time.time())}", "current_juz": 30}
    status_adm_stu, res_adm_stu = rest_request("POST", "students", token=admin_token, data=admin_stu)
    assert status_adm_stu in (200, 201), f"Admin failed to create student: {res_adm_stu}"
    target_stu_id = res_adm_stu[0]["id"]
    print(f"Admin enrolled student: {target_stu_id}")

    # Parent attempts unauthorized DELETE on student
    print("Attempting unauthorized DELETE on student as Parent...")
    status_stu_del, res_stu_del = rest_request("DELETE", f"students?id=eq.{target_stu_id}", token=parent_token)
    print(f"Parent Student DELETE Response: status={status_stu_del}, body={res_stu_del}")
    assert status_stu_del in (401, 403) or (status_stu_del == 200 and len(res_stu_del) == 0), \
        f"Security Breach: Parent was able to delete student: {res_stu_del}"

    # Verify student still exists
    status_chk_stu, res_chk_stu = rest_request("GET", f"students?id=eq.{target_stu_id}", token=admin_token)
    assert len(res_chk_stu) == 1, "Security Breach: Student was deleted by parent!"
    print("[PASS] Unauthorized Students DELETE blocked: Student persists.")

    # Cleanup student by Admin
    rest_request("DELETE", f"students?id=eq.{target_stu_id}", token=admin_token)
    results["Attack 3: Unauthorized Students INSERT/DELETE"] = True

    # ==========================================================================
    # ATTACK 4: Parent_Students Unauthorized Cross-Parent Access & Leaks
    # ==========================================================================
    print("\n" + "=" * 60)
    print("ATTACK 4: Cross-Parent Data Isolation in parent_students")
    print("=" * 60)

    # Let Admin create 2 students: one for Parent A (our challenger parent), one for Parent B (foreign parent)
    foreign_parent_id = "44ff1955-aafe-4ebc-913d-91e4c8634b85"
    stu_a_payload = {"full_name": f"Child of Parent A {int(time.time())}"}
    stu_b_payload = {"full_name": f"Child of Parent B {int(time.time())}"}

    _, res_a = rest_request("POST", "students", token=admin_token, data=stu_a_payload)
    _, res_b = rest_request("POST", "students", token=admin_token, data=stu_b_payload)
    student_a_id = res_a[0]["id"]
    student_b_id = res_b[0]["id"]

    # Admin links student_a to parent_id, and student_b to foreign_parent_id
    rest_request("POST", "parent_students", token=admin_token, data={"parent_id": parent_id, "student_id": student_a_id})
    rest_request("POST", "parent_students", token=admin_token, data={"parent_id": foreign_parent_id, "student_id": student_b_id})

    # Parent queries all parent_students
    print("Parent A querying parent_students...")
    status_ps, res_ps = rest_request("GET", "parent_students", token=parent_token)
    assert status_ps == 200, f"Failed to query parent_students: {res_ps}"
    print(f"Parent A received {len(res_ps)} records.")
    for rec in res_ps:
        assert rec["parent_id"] == parent_id, f"Security Breach: Parent A can see Parent B's link: {rec}"
    print("[PASS] Cross-parent records invisible in general SELECT.")

    # Parent A specifically queries foreign parent's link by parent_id filter
    print("Parent A targeting foreign parent's records via query filter...")
    status_foreign, res_foreign = rest_request("GET", f"parent_students?parent_id=eq.{foreign_parent_id}", token=parent_token)
    assert status_foreign == 200 and len(res_foreign) == 0, f"Security Breach: Foreign parent records leaked: {res_foreign}"
    print("[PASS] Targeted foreign parent queries return 0 rows.")

    # Parent A attempts to inject a link for Parent B
    print("Parent A attempting to link student to foreign parent...")
    status_inject, res_inject = rest_request("POST", "parent_students", token=parent_token, data={"parent_id": foreign_parent_id, "student_id": student_a_id})
    assert status_inject in (401, 403) or (isinstance(res_inject, dict) and res_inject.get("code") == "42501"), \
        f"Security Breach: Parent A injected link for another parent: {res_inject}"
    print("[PASS] Unauthorized parent_students link injection blocked by RLS.")

    # Cleanup
    rest_request("DELETE", f"parent_students?student_id=eq.{student_a_id}", token=admin_token)
    rest_request("DELETE", f"parent_students?student_id=eq.{student_b_id}", token=admin_token)
    rest_request("DELETE", f"students?id=eq.{student_a_id}", token=admin_token)
    rest_request("DELETE", f"students?id=eq.{student_b_id}", token=admin_token)
    results["Attack 4: Cross-Parent Isolation in parent_students"] = True

    # ==========================================================================
    # POSITIVE TEST: Admin & Teacher Legitimate Privileges
    # ==========================================================================
    print("\n" + "=" * 60)
    print("POSITIVE TEST: Valid Admin & Teacher Authorized Operations")
    print("=" * 60)

    # 1. Admin creates announcement
    adm_ann = {"title": "Legit Admin Announcement", "content": "Valid broadcast"}
    st_ann, res_ann = rest_request("POST", "announcements", token=admin_token, data=adm_ann)
    assert st_ann in (200, 201), f"Admin announcement creation failed: {res_ann}"
    legit_ann_id = res_ann[0]["id"]
    print(f"[PASS] Admin successfully created announcement: {legit_ann_id}")

    # 2. Admin creates halaqah assigned to Teacher
    adm_hal = {"name": f"Teacher Circle {int(time.time())}", "teacher_id": teacher_id, "schedule": "Mon-Wed 5 PM"}
    st_hal, res_hal = rest_request("POST", "halaqahs", token=admin_token, data=adm_hal)
    assert st_hal in (200, 201), f"Admin halaqah creation failed: {res_hal}"
    legit_hal_id = res_hal[0]["id"]
    print(f"[PASS] Admin successfully created halaqah: {legit_hal_id}")

    # 3. Teacher updates assigned halaqah
    teach_update = {"description": "Updated by assigned ustaz"}
    st_t_up, res_t_up = rest_request("PATCH", f"halaqahs?id=eq.{legit_hal_id}", token=teacher_token, data=teach_update)
    assert st_t_up == 200 and len(res_t_up) == 1, f"Teacher failed to update assigned halaqah: {res_t_up}"
    print(f"[PASS] Teacher successfully updated assigned halaqah: {res_t_up[0]['description']}")

    # 4. Teacher enrolls a student (Admins and teachers manage students)
    teach_stu = {"full_name": f"Ustaz Enrolled Student {int(time.time())}", "halaqah_id": legit_hal_id}
    st_t_stu, res_t_stu = rest_request("POST", "students", token=teacher_token, data=teach_stu)
    assert st_t_stu in (200, 201), f"Teacher failed to enroll student: {res_t_stu}"
    legit_stu_id = res_t_stu[0]["id"]
    print(f"[PASS] Teacher successfully enrolled student: {legit_stu_id}")

    # Cleanup positive test objects
    rest_request("DELETE", f"students?id=eq.{legit_stu_id}", token=admin_token)
    rest_request("DELETE", f"halaqahs?id=eq.{legit_hal_id}", token=admin_token)
    rest_request("DELETE", f"announcements?id=eq.{legit_ann_id}", token=admin_token)
    results["Positive Test: Admin & Teacher Authorized Operations"] = True

    # ==========================================================================
    # STORAGE PENETRATION: Buckets, Public Read, Unauthorized Write & Upsert
    # ==========================================================================
    print("\n" + "=" * 60)
    print("STORAGE PENETRATION: Buckets, Public Read, Write Protection & Upsert")
    print("=" * 60)

    test_buckets = ["announcement_attachments", "chat_attachments", "voice_messages"]
    test_content = b"CHALLENGER_STORAGE_PAYLOAD_TEST_DATA_M4"
    updated_content = b"CHALLENGER_STORAGE_PAYLOAD_TEST_DATA_M4_UPDATED_UPSERT"

    for bucket in test_buckets:
        print(f"\n--- Testing Storage Bucket: '{bucket}' ---")
        test_path = f"challenge/{int(time.time())}_{bucket}.bin"

        # 1. Unauthenticated WRITE attempt (MUST FAIL with 400/401/403 AccessDenied or missing auth)
        print(f"Testing unauthenticated WRITE to {bucket}/{test_path}...")
        anon_st, anon_res = storage_request("POST", f"object/{bucket}/{test_path}", token=None, data=test_content)
        print(f"Unauthenticated WRITE response: status={anon_st}, body={anon_res.decode() if isinstance(anon_res, bytes) else anon_res}")
        assert anon_st in (400, 401, 403), f"Security Breach: Unauthenticated write succeeded on '{bucket}'! Status: {anon_st}"
        print(f"[PASS] Unauthenticated write rejected (status {anon_st})")

        # 2. Authenticated WRITE (MUST SUCCEED)
        print(f"Testing authenticated WRITE to {bucket}/{test_path}...")
        auth_st, auth_res = storage_request("POST", f"object/{bucket}/{test_path}", token=admin_token, data=test_content)
        assert auth_st in (200, 201), f"Authenticated upload failed on '{bucket}': {auth_st} {auth_res}"
        print(f"[PASS] Authenticated write succeeded (status {auth_st})")

        # 3. Unauthenticated Public GET (MUST SUCCEED with 200 & exact content)
        pub_url = f"{BASE_URL}/storage/v1/object/public/{bucket}/{test_path}"
        print(f"Testing unauthenticated public GET from {pub_url}...")
        get_status, read_data = public_get_with_retry(pub_url, timeout=25)
        assert get_status == 200, f"Public GET failed on '{bucket}': {get_status}"
        assert read_data == test_content, f"Data corrupted on public GET from '{bucket}'!"
        print(f"[PASS] Unauthenticated public GET succeeded: 200 OK, {len(read_data)} bytes matched.")

        # 4. Authenticated UPDATE (upsert: true) (MUST SUCCEED)
        print(f"Testing authenticated UPDATE (upsert: true) on {bucket}/{test_path}...")
        up_st, up_res = storage_request("POST", f"object/{bucket}/{test_path}", token=admin_token, data=updated_content, upsert=True)
        assert up_st in (200, 201), f"Authenticated upsert failed on '{bucket}': {up_st} {up_res}"
        print(f"[PASS] Authenticated update (upsert) succeeded (status {up_st})")

        # Verify updated content via public GET (using cache-buster query parameter to bypass edge CDN cache)
        up_get_status, up_read_data = public_get_with_retry(f"{pub_url}?cb={int(time.time() * 1000)}", timeout=25)
        assert up_get_status == 200
        assert up_read_data == updated_content
        print(f"[PASS] Verified updated content served publicly.")

        # Cleanup
        del_st, _ = storage_request("DELETE", f"object/{bucket}/{test_path}", token=admin_token)
        print(f"Cleaned up test object in {bucket}: status {del_st}")

    results["Storage: Public Read, Write Protection & Upsert"] = True

    # ==========================================================================
    # FINAL SUMMARY
    # ==========================================================================
    print("\n" + "=" * 80)
    print("ADVERSARIAL CHALLENGE SUMMARY")
    print("=" * 80)
    all_ok = True
    for name, passed in results.items():
        st = "[PASS]" if passed else "[FAIL]"
        print(f"  {name:60}: {st}")
        if not passed:
            all_ok = False

    print("=" * 80)
    if all_ok:
        print(">>> ALL ADVERSARIAL PENETRATION & RLS TESTS PASSED WITH 100% SUCCESS! <<<")
        sys.exit(0)
    else:
        print(">>> SOME ADVERSARIAL TESTS FAILED! <<<")
        sys.exit(1)

if __name__ == "__main__":
    run_tests()
