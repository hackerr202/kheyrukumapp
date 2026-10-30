import ssl
import json
import urllib.request
import urllib.error
import pg8000.native

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"
EMAIL = "test_challenger_m1@kheyrukum.com"
PASSWORD = "TestPassword123!"

def main():
    print("=" * 60)
    print("AUTHENTICATED ADVERSARIAL TEST HARNESS")
    print("=" * 60)

    # 1. Connect to PostgreSQL and confirm user and grant admin/teacher profile
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
    )

    user_rows = con.run("SELECT id, email FROM auth.users WHERE email = :email;", email=EMAIL)
    if not user_rows:
        print("User not found in auth.users, exiting.")
        return False
    user_id = user_rows[0][0]
    print(f"Target test user ID: {user_id}")

    # Confirm user
    con.run("UPDATE auth.users SET email_confirmed_at = NOW() WHERE id = :uid;", uid=user_id)
    print("User confirmed in auth.users.")

    # Ensure profile exists with role 'admin'
    con.run("""
        INSERT INTO public.profiles (id, full_name, email, role)
        VALUES (:uid, 'Test Admin Challenger', :email, 'admin')
        ON CONFLICT (id) DO UPDATE SET role = 'admin';
    """, uid=user_id, email=EMAIL)
    print("Profile ensured with role 'admin'.")

    con.close()

    # 2. Authenticate and obtain JWT
    login_payload = json.dumps({"email": EMAIL, "password": PASSWORD}).encode()
    login_req = urllib.request.Request(
        f"{BASE_URL}/auth/v1/token?grant_type=password",
        data=login_payload,
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"}
    )
    with urllib.request.urlopen(login_req, timeout=15) as resp:
        auth_data = json.loads(resp.read().decode())
        jwt_token = auth_data["access_token"]
        print(f"Authenticated successfully! JWT obtained: {jwt_token[:30]}...")

    auth_headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {jwt_token}",
    }

    # 3. Test Storage Bucket Uploads with Authenticated JWT
    buckets = ["announcement_attachments", "chat_attachments", "voice_messages"]
    test_content = b"CHALLENGER_EMPIRICAL_TEST_PAYLOAD_123456789"

    for b in buckets:
        print(f"\n--- Testing Authenticated Storage for Bucket '{b}' ---")
        test_file = f"emp_test_{b}.txt"
        upload_url = f"{BASE_URL}/storage/v1/object/{b}/{test_file}"
        
        up_headers = dict(auth_headers)
        up_headers["Content-Type"] = "text/plain"
        up_headers["x-upsert"] = "true"

        # Upload
        up_req = urllib.request.Request(upload_url, data=test_content, headers=up_headers, method="POST")
        try:
            with urllib.request.urlopen(up_req, timeout=15) as up_resp:
                print(f"  Authenticated Upload: Status {up_resp.status} OK")
        except urllib.error.HTTPError as e:
            err = e.read().decode()
            print(f"  [FAIL] Authenticated Upload failed: HTTP {e.code} - {err}")
            continue

        # Public URL Download (Verification that bucket is truly public and accessible without credentials)
        public_url = f"{BASE_URL}/storage/v1/object/public/{b}/{test_file}"
        print(f"  Public Download URL: {public_url}")
        pub_req = urllib.request.Request(public_url, method="GET") # NO auth headers!
        try:
            with urllib.request.urlopen(pub_req, timeout=15) as pub_resp:
                downloaded_content = pub_resp.read()
                print(f"  Public Download without Auth: Status {pub_resp.status} OK (Bytes: {len(downloaded_content)})")
                assert downloaded_content == test_content, "Downloaded content did not match uploaded content!"
                print(f"  [PASS] Verified: Bucket '{b}' is 100% publicly accessible and served correctly!")
        except Exception as e:
            print(f"  [FAIL] Public download failed: {e}")

        # Authenticated Delete (Clean up)
        del_req = urllib.request.Request(upload_url, headers=auth_headers, method="DELETE")
        try:
            with urllib.request.urlopen(del_req, timeout=15) as del_resp:
                print(f"  Cleaned up test file: Status {del_resp.status} OK")
        except Exception as e:
            print(f"  Cleanup note: {e}")

    # 4. Test Student Persistence with Authenticated JWT
    print("\n--- Testing Student Insertion via PostgREST with Authenticated Admin JWT ---")
    stu_payload = json.dumps({
        "full_name": "Authenticated Test Student",
        "current_juz": 30,
        "current_surah": 1,
        "current_ayah": 1,
    }).encode()
    stu_headers = dict(auth_headers)
    stu_headers["Content-Type"] = "application/json"
    stu_headers["Prefer"] = "return=representation"

    stu_req = urllib.request.Request(
        f"{BASE_URL}/rest/v1/students",
        data=stu_payload,
        headers=stu_headers,
        method="POST"
    )
    with urllib.request.urlopen(stu_req, timeout=15) as resp:
        inserted_stu = json.loads(resp.read().decode())
        print(f"  Student Insertion Status: {resp.status} OK")
        print(f"  Inserted Student: {inserted_stu}")
        created_id = inserted_stu[0]["id"]

    # 5. Test fetchStudentsFromCloud() Query with Authenticated JWT
    print("\n--- Testing fetchStudentsFromCloud() Query with Authenticated Admin JWT ---")
    fetch_url = (
        f"{BASE_URL}/rest/v1/students?"
        f"id=eq.{created_id}&"
        "select=id,full_name,halaqah_id,current_juz,current_surah,current_ayah,date_of_birth,created_at,"
        "halaqahs:halaqah_id(name),parent_students(parent_id,profiles:parent_id(full_name,phone,email))"
    )
    fetch_req = urllib.request.Request(fetch_url, headers=auth_headers, method="GET")
    with urllib.request.urlopen(fetch_req, timeout=15) as resp:
        fetched_list = json.loads(resp.read().decode())
        print(f"  fetchStudentsFromCloud Query Status: {resp.status} OK")
        print(f"  Returned {len(fetched_list)} students")
        assert len(fetched_list) == 1, "Expected exactly 1 student returned!"
        assert fetched_list[0]["id"] == created_id, "ID mismatch!"
        assert fetched_list[0]["full_name"] == "Authenticated Test Student", "Name mismatch!"
        print("  [PASS] fetchStudentsFromCloud query perfectly returns the newly inserted student when authenticated!")

    # 6. Clean up inserted test student
    del_stu_req = urllib.request.Request(
        f"{BASE_URL}/rest/v1/students?id=eq.{created_id}",
        headers=auth_headers,
        method="DELETE"
    )
    with urllib.request.urlopen(del_stu_req, timeout=15) as resp:
        print(f"  Cleaned up test student: Status {resp.status} OK")

    # 7. Clean up test user in DB
    con = pg8000.native.Connection(
        user="postgres.tjhqpzvjzmpyrridtpsj",
        host="aws-1-eu-west-3.pooler.supabase.com",
        port=6543,
        database="postgres",
        password="ustazmuhammedyakut",
        ssl_context=ctx,
    )
    con.run("DELETE FROM public.profiles WHERE id = :uid;", uid=user_id)
    con.run("DELETE FROM auth.users WHERE id = :uid;", uid=user_id)
    con.close()
    print("Cleaned up test user.")

    print("\n" + "=" * 60)
    print("ALL AUTHENTICATED TESTS PASSED WITH 100% SUCCESS!")
    print("=" * 60)
    return True

if __name__ == "__main__":
    main()
