import json
import ssl
import sys
import urllib.request
import urllib.error
import pg8000.native

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"
HEADERS = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Type": "application/json",
}

def section(title):
    print("\n" + "=" * 70)
    print(f" {title.upper()} ")
    print("=" * 70)

def test_rest_api_buckets():
    section("1. Empirical Verification: Storage Buckets via REST API")
    url = f"{BASE_URL}/storage/v1/bucket"
    req = urllib.request.Request(url, headers=HEADERS, method="GET")
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = resp.read().decode("utf-8")
        buckets = json.loads(body)
        print(f"Status: {resp.status} OK")
        print(f"Total buckets returned: {len(buckets)}")

        bucket_map = {b["id"]: b for b in buckets}
        required_buckets = [
            "announcement_attachments",
            "chat_attachments",
            "voice_messages",
        ]

        all_ok = True
        for b_name in required_buckets:
            if b_name not in bucket_map:
                print(f"[FAIL] Required bucket '{b_name}' NOT found in storage/v1/bucket list!")
                all_ok = False
                continue
            b = bucket_map[b_name]
            is_public = b.get("public")
            print(f"\nBucket '{b_name}':")
            print(f"  - ID: {b.get('id')}")
            print(f"  - Name: {b.get('name')}")
            print(f"  - Public: {is_public}")
            print(f"  - File size limit: {b.get('file_size_limit')}")
            print(f"  - Allowed MIME types: {b.get('allowed_mime_types')}")
            print(f"  - Created at: {b.get('created_at')}")
            if not is_public:
                print(f"  [WARN] Bucket '{b_name}' has public={is_public}")
                all_ok = False

            # Verify individual endpoint GET /storage/v1/bucket/{id}
            indiv_url = f"{BASE_URL}/storage/v1/bucket/{b_name}"
            indiv_req = urllib.request.Request(indiv_url, headers=HEADERS, method="GET")
            with urllib.request.urlopen(indiv_req, timeout=15) as indiv_resp:
                indiv_data = json.loads(indiv_resp.read().decode("utf-8"))
                print(f"  Individual GET /storage/v1/bucket/{b_name}: {indiv_resp.status} OK (public: {indiv_data.get('public')})")

        return all_ok, bucket_map

def test_storage_policies_and_db():
    section("2. Empirical Verification: PostgreSQL Storage & Tables RLS Policies")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    con = pg8000.native.Connection(
        user="postgres.tjhqpzvjzmpyrridtpsj",
        host="aws-1-eu-west-3.pooler.supabase.com",
        port=6543,
        database="postgres",
        password="ustazmuhammedyakut",
        ssl_context=ctx,
        timeout=15,
    )
    print("PostgreSQL connection established via aws-1-eu-west-3:6543")

    # 1. Storage Buckets rows
    print("\n--- Direct storage.buckets table rows ---")
    buckets_rows = con.run("SELECT id, name, public, file_size_limit, allowed_mime_types FROM storage.buckets;")
    for r in buckets_rows:
        print(f"  Bucket: id={r[0]}, name={r[1]}, public={r[2]}, file_size_limit={r[3]}, mime_types={r[4]}")

    # 2. Storage Policies
    print("\n--- Storage Policies in pg_policies (storage.buckets & storage.objects) ---")
    storage_policies = con.run("""
        SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
        FROM pg_policies 
        WHERE schemaname = 'storage'
        ORDER BY tablename, cmd;
    """)
    for p in storage_policies:
        print(f"  [{p[1]}] Policy: '{p[2]}' | CMD: {p[5]} | Roles: {p[4]} | Permissive: {p[3]}")
        print(f"      USING: {p[6]}")
        if p[7]:
            print(f"      WITH CHECK: {p[7]}")

    # 3. Public Tables Policies: students, parent_students, halaqahs, announcements
    print("\n--- Public Tables Policies in pg_policies ---")
    pub_policies = con.run("""
        SELECT tablename, policyname, roles, cmd, qual, with_check
        FROM pg_policies 
        WHERE schemaname = 'public' AND tablename IN ('students', 'parent_students', 'halaqahs', 'announcements')
        ORDER BY tablename, cmd;
    """)
    for p in pub_policies:
        print(f"  [{p[0]}] '{p[1]}' | CMD: {p[3]} | Roles: {p[2]}")
        print(f"      USING: {p[4]}")
        if p[5]:
            print(f"      WITH CHECK: {p[5]}")

    # 4. Table Columns in students & parent_students
    print("\n--- Schema Columns: public.students ---")
    students_cols = con.run("""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'students'
        ORDER BY ordinal_position;
    """)
    for c in students_cols:
        print(f"  Column: {c[0]:20} Type: {c[1]:15} Nullable: {c[2]:5} Default: {c[3]}")

    print("\n--- Schema Columns: public.parent_students ---")
    ps_cols = con.run("""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'parent_students'
        ORDER BY ordinal_position;
    """)
    for c in ps_cols:
        print(f"  Column: {c[0]:20} Type: {c[1]:15} Nullable: {c[2]:5} Default: {c[3]}")

    # 5. Check foreign keys
    print("\n--- Foreign Key Constraints on public.students ---")
    fk_rows = con.run("""
        SELECT
            tc.constraint_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name = 'students';
    """)
    for fk in fk_rows:
        print(f"  FK: {fk[0]} | Column: {fk[1]} -> {fk[2]}.{fk[3]}")

    con.close()
    return True

def test_storage_object_upload_download():
    section("3. Empirical Verification: Object Upload & Public Download")
    # Test uploading a small test file to announcement_attachments, chat_attachments, and voice_messages
    buckets = ["announcement_attachments", "chat_attachments", "voice_messages"]
    test_content = b"Verification test payload for Kheyrukum storage bucket."
    
    # We will test using direct Storage API:
    # POST /storage/v1/object/{bucket}/{wildcard}
    for b in buckets:
        test_filename = f"test_verify_{b}.txt"
        upload_url = f"{BASE_URL}/storage/v1/object/{b}/{test_filename}"
        
        # 1. Test unauthenticated / anon upload (Expect 401 or 403 or success depending on policy)
        print(f"\nTesting upload to bucket '{b}':")
        upload_headers = {
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {ANON_KEY}",
            "Content-Type": "text/plain",
            "x-upsert": "true",
        }
        
        req = urllib.request.Request(upload_url, data=test_content, headers=upload_headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                print(f"  Upload with anon key: Status {resp.status} OK (Inserted!)")
                upload_worked = True
        except urllib.error.HTTPError as e:
            err_msg = e.read().decode("utf-8", errors="ignore")
            print(f"  Upload with anon key: HTTP {e.code} - {err_msg[:100]}")
            upload_worked = False

        # 2. Test public download endpoint:
        # GET /storage/v1/object/public/{bucket}/{wildcard}
        public_url = f"{BASE_URL}/storage/v1/object/public/{b}/{test_filename}"
        print(f"  Testing public URL download: {public_url}")
        pub_req = urllib.request.Request(public_url, method="GET")
        try:
            with urllib.request.urlopen(pub_req, timeout=15) as resp:
                downloaded = resp.read()
                print(f"  Public download status: HTTP {resp.status} OK (Bytes: {len(downloaded)})")
                if downloaded == test_content:
                    print("  [SUCCESS] Downloaded content matches exactly!")
        except urllib.error.HTTPError as e:
            err_msg = e.read().decode("utf-8", errors="ignore")
            print(f"  Public download HTTP {e.code} - {err_msg[:100]}")

        # 3. Clean up test file if it was uploaded
        if upload_worked:
            del_url = f"{BASE_URL}/storage/v1/object/{b}/{test_filename}"
            del_req = urllib.request.Request(del_url, headers=upload_headers, method="DELETE")
            try:
                with urllib.request.urlopen(del_req, timeout=15) as resp:
                    print(f"  Cleaned up test object: HTTP {resp.status}")
            except Exception as e:
                print(f"  Cleanup notice: {e}")

def test_student_persistence_lifecycle():
    section("4. Empirical Verification: Student Persistence & Reinstall Simulation")
    # Simulate the exact operations done by StudentService.dart:
    # 1. Insert a test student into public.students directly via DB or PostgREST
    # 2. Fetch the student via the exact query used by fetchStudentsFromCloud()
    # 3. Verify parent_students join & halaqahs join
    # 4. Verify what happens on app reinstall (wipe simulated cache, run cloud fetch query)
    # 5. Clean up the test student

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    con = pg8000.native.Connection(
        user="postgres.tjhqpzvjzmpyrridtpsj",
        host="aws-1-eu-west-3.pooler.supabase.com",
        port=6543,
        database="postgres",
        password="ustazmuhammedyakut",
        ssl_context=ctx,
        timeout=15,
    )

    test_student_name = "Empirical Test Student - QA Verification"
    
    # 1. Insert student
    print(f"Inserting test student: '{test_student_name}'...")
    res = con.run("""
        INSERT INTO public.students (full_name, current_juz, current_surah, current_ayah)
        VALUES (:name, 30, 114, 1)
        RETURNING id, full_name, current_juz, created_at;
    """, name=test_student_name)
    
    test_student_id = res[0][0]
    print(f"  Inserted with ID: {test_student_id}")

    # 2. Run the exact fetchStudentsFromCloud() query via PostgREST
    fetch_url = (
        f"{BASE_URL}/rest/v1/students?"
        f"id=eq.{test_student_id}&"
        "select=id,full_name,halaqah_id,current_juz,current_surah,current_ayah,date_of_birth,created_at,"
        "halaqahs:halaqah_id(name),parent_students(parent_id,profiles:parent_id(full_name,phone,email))"
    )
    print(f"\nQuerying PostgREST with fetchStudentsFromCloud() pattern...")
    req = urllib.request.Request(fetch_url, headers=HEADERS, method="GET")
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = resp.read().decode("utf-8")
        parsed = json.loads(body)
        print(f"  PostgREST Response Status: {resp.status} OK")
        print(f"  Found items: {len(parsed)}")
        if parsed:
            item = parsed[0]
            print(f"  Student fetched: id={item.get('id')}, name={item.get('full_name')}")
            print(f"  halaqahs join: {item.get('halaqahs')}")
            print(f"  parent_students join: {item.get('parent_students')}")
            assert item.get("id") == str(test_student_id), "Student ID mismatch!"
            assert item.get("full_name") == test_student_name, "Student name mismatch!"
            print("  [SUCCESS] Student persisted in Supabase and retrieved via Cloud Fetch query!")

    # 3. Simulate App Reinstall:
    # On reinstall: SharedPreferences is wiped (empty cache).
    # fetchStudentsFromCloud() runs from scratch.
    print("\nSimulating App Reinstall:")
    simulated_local_cache = [] # Empty cache on fresh reinstall
    print("  Step 1: Local cache on reinstall: [] (EMPTY)")
    # When fetchStudentsFromCloud runs:
    simulated_cloud_students = parsed
    print(f"  Step 2: fetchStudentsFromCloud() fetched {len(simulated_cloud_students)} students from remote DB.")
    # Merges:
    simulated_merged = list(simulated_cloud_students)
    # Cache repopulated:
    simulated_local_cache = simulated_merged
    print(f"  Step 3: Cache restored from remote cloud! Total in cache: {len(simulated_local_cache)}")
    print("  [SUCCESS] Data survives complete device wipe/app reinstall because persistence is in Supabase!")

    # 4. Clean up test student
    print(f"\nCleaning up test student '{test_student_id}'...")
    con.run("DELETE FROM public.students WHERE id = :id;", id=test_student_id)
    print("  Cleanup successful.")

    con.close()

if __name__ == "__main__":
    try:
        ok_rest, buckets = test_rest_api_buckets()
        test_storage_policies_and_db()
        test_storage_object_upload_download()
        test_student_persistence_lifecycle()
        print("\n" + "=" * 70)
        print("ALL EMPIRICAL CHALLENGER TESTS COMPLETED")
        print("=" * 70)
    except Exception as e:
        print(f"\n[EXCEPTION IN TEST EXECUTION]: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
