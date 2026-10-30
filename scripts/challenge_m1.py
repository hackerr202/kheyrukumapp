import os
import sys
import ssl
import json
import uuid
import urllib.request
import urllib.error
import pg8000.native

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"

# Read authenticated token if available
TOKEN_FILE = os.path.join(os.path.dirname(__file__), "..", "test_token.txt")
AUTH_TOKEN = None
if os.path.exists(TOKEN_FILE):
    with open(TOKEN_FILE, "r") as f:
        AUTH_TOKEN = f.read().strip()

POOLER_HOST = "aws-1-eu-west-3.pooler.supabase.com"
POOLER_PORT = 5432  # Session mode pooler supports prepared statements
DB_USER = "postgres.tjhqpzvjzmpyrridtpsj"
DB_PASS = "ustazmuhammedyakut"
DB_NAME = "postgres"

def get_db_connection():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    conn = pg8000.native.Connection(
        user=DB_USER,
        host=POOLER_HOST,
        port=POOLER_PORT,
        database=DB_NAME,
        password=DB_PASS,
        ssl_context=ctx,
        timeout=15
    )
    return conn

def http_request(path, method="GET", data=None, token=None, extra_headers=None):
    url = f"{BASE_URL}{path}"
    bearer = token if token else ANON_KEY
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {bearer}",
        "Content-Type": "application/json",
    }
    if extra_headers:
        headers.update(extra_headers)

    req_data = None
    if data is not None:
        if isinstance(data, (dict, list)):
            req_data = json.dumps(data).encode("utf-8")
        elif isinstance(data, (bytes, bytearray)):
            req_data = data
        else:
            req_data = str(data).encode("utf-8")

    req = urllib.request.Request(url, headers=headers, method=method, data=req_data)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read()
            resp_headers = dict(resp.headers)
            try:
                parsed = json.loads(body.decode("utf-8"))
            except Exception:
                parsed = body
            return resp.status, resp_headers, parsed
    except urllib.error.HTTPError as e:
        body = e.read()
        resp_headers = dict(e.headers)
        try:
            parsed = json.loads(body.decode("utf-8", errors="ignore"))
        except Exception:
            parsed = body.decode("utf-8", errors="ignore")
        return e.code, resp_headers, parsed
    except Exception as e:
        return 0, {}, str(e)

def run_adversarial_challenges():
    print("=" * 75)
    print("CHALLENGER 1: ADVERSARIAL EMPIRICAL VERIFICATION (MILESTONE 1)")
    print("=" * 75)

    if not AUTH_TOKEN:
        print("[ERROR] Auth token file not found. Run get_test_token.py first.")
        return False

    db = get_db_connection()
    print(f"[INIT] Direct PostgreSQL connection established via {POOLER_HOST}:{POOLER_PORT}")
    print(f"[INIT] Authenticated JWT token loaded ({len(AUTH_TOKEN)} chars)\n")

    results = {}

    # -------------------------------------------------------------------------
    # CHALLENGE 1: Announcements Schema Verification & PostgREST Cache Check
    # -------------------------------------------------------------------------
    print("--- CHALLENGE 1: Announcements Schema Cache (attachment_name, attachment_url) ---")
    
    # 1a. Query with ANON key
    st_anon, hdrs_anon, body_anon = http_request(
        "/rest/v1/announcements?select=id,title,attachment_name,attachment_url"
    )
    print(f"GET /rest/v1/announcements (anon key) -> HTTP {st_anon}")
    # Verify no PGRST204 code in anon request
    is_pgrst204_anon = (isinstance(body_anon, dict) and body_anon.get("code") == "PGRST204")
    print(f"  PGRST204 present on anon GET: {is_pgrst204_anon}")

    # 1b. Query with AUTHENTICATED token
    st_auth, hdrs_auth, body_auth = http_request(
        "/rest/v1/announcements?select=id,title,attachment_name,attachment_url",
        token=AUTH_TOKEN
    )
    print(f"GET /rest/v1/announcements (authenticated token) -> HTTP {st_auth}")
    is_pgrst204_auth = (isinstance(body_auth, dict) and body_auth.get("code") == "PGRST204")
    print(f"  PGRST204 present on auth GET: {is_pgrst204_auth}")

    ch1_pass = (st_anon == 200 and not is_pgrst204_anon and st_auth == 200 and not is_pgrst204_auth)
    results["announcements_pgrst204_eliminated"] = ch1_pass
    print(f"Challenge 1 Result: {'[PASS]' if ch1_pass else '[FAIL]'}\n")

    # -------------------------------------------------------------------------
    # CHALLENGE 2: Announcements Insert & Fetch with Real Attachment Fields
    # -------------------------------------------------------------------------
    print("--- CHALLENGE 2: Announcements Insertion & Retrieval via PostgREST ---")
    test_ann_id = str(uuid.uuid4())
    test_ann_title = f"Adversarial Announcement {test_ann_id[:8]}"
    test_ann_file = "official_curriculum_circular.pdf"
    test_ann_url = f"{BASE_URL}/storage/v1/object/public/announcement_attachments/{test_ann_file}"
    
    ann_payload = {
        "id": test_ann_id,
        "title": test_ann_title,
        "content": "Official circular containing curriculum updates and attachment links.",
        "attachment_name": test_ann_file,
        "attachment_url": test_ann_url,
        "target_audience": "all",
        "author_name": "Ustaz Muhammed Yakut",
        "is_pinned": True,
    }

    # Execute POST /rest/v1/announcements via PostgREST with Authenticated token
    st_post, hdrs_post, body_post = http_request(
        "/rest/v1/announcements",
        method="POST",
        data=ann_payload,
        token=AUTH_TOKEN,
        extra_headers={"Prefer": "return=representation"}
    )
    print(f"POST /rest/v1/announcements (authenticated) -> HTTP {st_post}")
    post_ok = False
    if st_post == 201 and isinstance(body_post, list) and len(body_post) > 0:
        inserted = body_post[0]
        if inserted.get("attachment_name") == test_ann_file and inserted.get("attachment_url") == test_ann_url:
            post_ok = True
            print(f"  [PASS] Insert returned exact attachment fields: name='{inserted.get('attachment_name')}', url='{inserted.get('attachment_url')}'")
        else:
            print(f"  [FAIL] Returned data mismatch: {inserted}")
    else:
        print(f"  [FAIL] PostgREST insert failed: {body_post}")

    # Now verify GET from PostgREST
    st_fetch, hdrs_fetch, body_fetch = http_request(
        f"/rest/v1/announcements?select=id,title,attachment_name,attachment_url,is_pinned&id=eq.{test_ann_id}",
        token=AUTH_TOKEN
    )
    print(f"GET /rest/v1/announcements?id=eq.{test_ann_id} -> HTTP {st_fetch}")
    fetch_ok = False
    if st_fetch == 200 and isinstance(body_fetch, list) and len(body_fetch) == 1:
        item = body_fetch[0]
        if item.get("attachment_name") == test_ann_file and item.get("attachment_url") == test_ann_url:
            fetch_ok = True
            print(f"  [PASS] Fetched row matches inserted attachment fields perfectly.")
        else:
            print(f"  [FAIL] Fetched fields mismatch: {item}")
    else:
        print(f"  [FAIL] Fetch failed: {body_fetch}")

    # Cleanup test announcement via PostgREST DELETE
    st_del, _, _ = http_request(
        f"/rest/v1/announcements?id=eq.{test_ann_id}",
        method="DELETE",
        token=AUTH_TOKEN
    )
    print(f"DELETE /rest/v1/announcements?id=eq.{test_ann_id} -> HTTP {st_del}")
    
    ch2_pass = (post_ok and fetch_ok and st_del in (200, 204))
    results["announcements_insert_and_retrieve_attachment"] = ch2_pass
    print(f"Challenge 2 Result: {'[PASS]' if ch2_pass else '[FAIL]'}\n")

    # -------------------------------------------------------------------------
    # CHALLENGE 3: Halaqahs Schema & Schedule Column Persistence
    # -------------------------------------------------------------------------
    print("--- CHALLENGE 3: Halaqahs Creation & Schedule Column ---")
    test_hal_id = str(uuid.uuid4())
    test_hal_name = "حلقة الإتقان والترتيل (Adversarial)"
    test_schedule = "Mon-Wed-Fri 16:30-18:30 EAT"
    test_desc = "Testing halaqah creation with schedule persistence."

    hal_payload = {
        "id": test_hal_id,
        "name": test_hal_name,
        "description": test_desc,
        "schedule": test_schedule,
    }

    # Execute POST /rest/v1/halaqahs via PostgREST
    st_hpost, _, body_hpost = http_request(
        "/rest/v1/halaqahs",
        method="POST",
        data=hal_payload,
        token=AUTH_TOKEN,
        extra_headers={"Prefer": "return=representation"}
    )
    print(f"POST /rest/v1/halaqahs (authenticated) -> HTTP {st_hpost}")
    hpost_ok = False
    if st_hpost == 201 and isinstance(body_hpost, list) and len(body_hpost) > 0:
        h_ins = body_hpost[0]
        if h_ins.get("schedule") == test_schedule and h_ins.get("name") == test_hal_name:
            hpost_ok = True
            print(f"  [PASS] Halaqah created with schedule='{h_ins.get('schedule')}'")
        else:
            print(f"  [FAIL] Halaqah creation payload mismatch: {h_ins}")
    else:
        print(f"  [FAIL] Halaqah creation failed: {body_hpost}")

    # Fetch halaqah back via PostgREST
    st_hget, _, body_hget = http_request(
        f"/rest/v1/halaqahs?select=id,name,description,schedule&id=eq.{test_hal_id}",
        token=AUTH_TOKEN
    )
    print(f"GET /rest/v1/halaqahs?id=eq.{test_hal_id} -> HTTP {st_hget}")
    hget_ok = False
    if st_hget == 200 and isinstance(body_hget, list) and len(body_hget) == 1:
        h_item = body_hget[0]
        if h_item.get("schedule") == test_schedule:
            hget_ok = True
            print(f"  [PASS] Retrieved halaqah schedule verified: '{h_item.get('schedule')}'")
    
    # Cleanup halaqah
    st_hdel, _, _ = http_request(
        f"/rest/v1/halaqahs?id=eq.{test_hal_id}",
        method="DELETE",
        token=AUTH_TOKEN
    )
    print(f"DELETE /rest/v1/halaqahs?id=eq.{test_hal_id} -> HTTP {st_hdel}")

    ch3_pass = (hpost_ok and hget_ok and st_hdel in (200, 204))
    results["halaqahs_schedule_column"] = ch3_pass
    print(f"Challenge 3 Result: {'[PASS]' if ch3_pass else '[FAIL]'}\n")

    # -------------------------------------------------------------------------
    # CHALLENGE 4: Students Cloud Fetch with Halaqahs and Parent-Students Joins
    # -------------------------------------------------------------------------
    print("--- CHALLENGE 4: Students Relational Joins (PostgREST Foreign Key Embedding) ---")
    
    # Fetch an existing parent profile
    parent_rows = db.run("SELECT id, full_name, phone, email FROM public.profiles WHERE role = 'parent' LIMIT 1")
    if not parent_rows:
        print("[FAIL] No parent profile found in database.")
        return False
    
    test_parent_id = str(parent_rows[0][0])
    test_parent_name = str(parent_rows[0][1])
    test_parent_phone = str(parent_rows[0][2])
    print(f"[DB] Using existing parent profile {test_parent_id} ('{test_parent_name}')")

    test_student_id = str(uuid.uuid4())
    test_circle_id = str(uuid.uuid4())

    try:
        # Create circle via direct DB
        db.run(
            "INSERT INTO public.halaqahs (id, name, schedule) "
            "VALUES (:id, 'حلقة الفرقان لتحفيظ القرآن', 'Daily 17:00-19:00')",
            id=test_circle_id
        )
        print(f"[DB] Inserted halaqah {test_circle_id}")

        # Create student via PostgREST with Authenticated token!
        student_payload = {
            "id": test_student_id,
            "full_name": "Bilal Ibn Rabah",
            "halaqah_id": test_circle_id,
            "current_juz": 5,
            "current_surah": 4,
            "current_ayah": 1,
            "date_of_birth": "2015-06-15"
        }
        st_stu_post, _, body_stu_post = http_request(
            "/rest/v1/students",
            method="POST",
            data=student_payload,
            token=AUTH_TOKEN,
            extra_headers={"Prefer": "return=representation"}
        )
        print(f"POST /rest/v1/students -> HTTP {st_stu_post}")

        # Create parent-student association via direct DB
        db.run(
            "INSERT INTO public.parent_students (parent_id, student_id) "
            "VALUES (:p_id, :s_id)",
            p_id=test_parent_id,
            s_id=test_student_id
        )
        print(f"[DB] Inserted parent_students link {test_parent_id} -> {test_student_id}")

        # Now execute the exact client join query through PostgREST!
        join_query = (
            f"/rest/v1/students?select=id,full_name,halaqah_id,current_juz,current_surah,current_ayah,date_of_birth,created_at,"
            f"halaqahs:halaqah_id(name),"
            f"parent_students(parent_id,profiles:parent_id(full_name,phone,email))"
            f"&id=eq.{test_student_id}"
        )
        st_join, _, body_join = http_request(join_query, token=AUTH_TOKEN)
        print(f"GET /rest/v1/students?...&id=eq.{test_student_id} -> HTTP {st_join}")

        join_pass = False
        if st_join == 200 and isinstance(body_join, list) and len(body_join) == 1:
            record = body_join[0]
            print(f"  Joined student record:\n{json.dumps(record, indent=4, ensure_ascii=False)}")
            
            # Verify embedded halaqah name
            h_obj = record.get("halaqahs")
            h_valid = isinstance(h_obj, dict) and h_obj.get("name") == "حلقة الفرقان لتحفيظ القرآن"

            # Verify embedded parent_students and profile
            ps_list = record.get("parent_students")
            ps_valid = False
            if isinstance(ps_list, list) and len(ps_list) > 0:
                p_item = ps_list[0]
                prof = p_item.get("profiles")
                if isinstance(prof, dict) and prof.get("full_name") == test_parent_name:
                    ps_valid = True

            print(f"  Halaqah embedded join valid: {h_valid}")
            print(f"  Parent profile embedded join valid: {ps_valid}")
            join_pass = (h_valid and ps_valid)
        else:
            print(f"  [FAIL] Relational join query failed: {body_join}")

        results["students_relational_joins"] = join_pass
        print(f"Challenge 4 Result: {'[PASS]' if join_pass else '[FAIL]'}\n")

    finally:
        # Clean up relational entities in reverse dependency order
        print("[CLEANUP] Cleaning up relational test records...")
        db.run("DELETE FROM public.parent_students WHERE student_id = :s_id", s_id=test_student_id)
        db.run("DELETE FROM public.students WHERE id = :s_id", s_id=test_student_id)
        db.run("DELETE FROM public.halaqahs WHERE id = :h_id", h_id=test_circle_id)
        print("[CLEANUP] All test records cleanly removed.\n")

    # -------------------------------------------------------------------------
    # CHALLENGE 5: Storage Buckets Functional Roundtrip (Upload, Public Read, Delete)
    # -------------------------------------------------------------------------
    print("--- CHALLENGE 5: Cloud Storage Buckets Functional Roundtrip ---")
    required_buckets = ["announcement_attachments", "chat_attachments", "voice_messages"]
    bucket_results = {}

    for b_name in required_buckets:
        file_name = f"challenge_test_{uuid.uuid4().hex[:6]}.txt"
        test_payload = f"Empirical verification ping for bucket '{b_name}' at {uuid.uuid4()}"
        
        # 1. Upload via Storage REST API (with authenticated token)
        upload_path = f"/storage/v1/object/{b_name}/{file_name}"
        st_up, hdrs_up, body_up = http_request(
            upload_path,
            method="POST",
            data=test_payload.encode("utf-8"),
            token=AUTH_TOKEN,
            extra_headers={"Content-Type": "text/plain"}
        )
        print(f"POST {upload_path} -> HTTP {st_up}")

        # 2. Public Read (unauthenticated HTTP GET, simulating end-user client download)
        public_url = f"/storage/v1/object/public/{b_name}/{file_name}"
        st_dl, hdrs_dl, body_dl = http_request(public_url, method="GET")
        print(f"GET {public_url} (public read) -> HTTP {st_dl}")

        content_matched = False
        if st_dl == 200:
            if isinstance(body_dl, bytes):
                dl_str = body_dl.decode("utf-8", errors="ignore")
            else:
                dl_str = str(body_dl)
            if dl_str == test_payload:
                content_matched = True
                print(f"  [PASS] Public read matched uploaded payload exactly.")
            else:
                print(f"  [FAIL] Downloaded payload mismatch: {dl_str}")
        else:
            print(f"  [FAIL] Public download failed: {body_dl}")

        # 3. Delete via Storage REST API
        del_path = f"/storage/v1/object/{b_name}"
        st_del, _, _ = http_request(
            del_path,
            method="DELETE",
            data={"prefixes": [file_name]},
            token=AUTH_TOKEN
        )
        print(f"DELETE {del_path} -> HTTP {st_del}")

        bucket_ok = (st_up in (200, 201) and content_matched and st_del in (200, 204))
        bucket_results[b_name] = bucket_ok
        print(f"Bucket '{b_name}' result: {'[PASS]' if bucket_ok else '[FAIL]'}")

    ch5_pass = all(bucket_results.values())
    results["storage_buckets_roundtrip"] = ch5_pass
    print(f"Challenge 5 Result: {'[PASS]' if ch5_pass else '[FAIL]'}\n")

    # -------------------------------------------------------------------------
    # CHALLENGE 6: Supabase Realtime Publications Verification
    # -------------------------------------------------------------------------
    print("--- CHALLENGE 6: Realtime Publications Verification ---")
    pub_rows = db.run(
        "SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime'"
    )
    published = {row[0] for row in pub_rows}
    print(f"Tables published to supabase_realtime: {published}")
    expected_realtime = {"halaqahs", "students", "conversations", "messages"}
    missing = expected_realtime - published
    ch6_pass = (len(missing) == 0)
    print(f"Missing realtime tables: {list(missing) if missing else 'None'}")
    results["realtime_publications"] = ch6_pass
    print(f"Challenge 6 Result: {'[PASS]' if ch6_pass else '[FAIL]'}\n")

    # Close DB
    db.close()

    # -------------------------------------------------------------------------
    # FINAL VERDICT
    # -------------------------------------------------------------------------
    print("=" * 75)
    print("CHALLENGER 1 EMPIRICAL RESULTS SUMMARY")
    print("=" * 75)
    all_ok = True
    for test_key, passed in results.items():
        tag = "[PASS]" if passed else "[FAIL]"
        print(f"  {test_key:45}: {tag}")
        if not passed:
            all_ok = False

    verdict = "APPROVE" if all_ok else "REJECT"
    print("\n" + "=" * 75)
    print(f"FINAL CHALLENGER VERDICT: {verdict}")
    print("=" * 75)
    return all_ok

if __name__ == "__main__":
    passed = run_adversarial_challenges()
    sys.exit(0 if passed else 1)
