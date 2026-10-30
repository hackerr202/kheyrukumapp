import urllib.request
import urllib.error
import json
import sys

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"
HEADERS = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Type": "application/json",
}

def check_endpoint(name, url, method="GET", data=None):
    print(f"\n--- Testing {name} ---")
    print(f"URL: {url}")
    req = urllib.request.Request(url, headers=HEADERS, method=method, data=data)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode("utf-8")
            print(f"Status: {resp.status} OK")
            try:
                parsed = json.loads(body)
                if isinstance(parsed, list):
                    print(f"Items returned: {len(parsed)}")
                    if parsed:
                        print(f"Sample item keys: {list(parsed[0].keys())}")
                elif isinstance(parsed, dict):
                    print(f"Response keys: {list(parsed.keys())}")
            except Exception:
                print(f"Raw body: {body[:150]}")
            return True, body
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="ignore")
        print(f"HTTPError: {e.code} - {err_body[:250]}")
        return False, err_body
    except Exception as e:
        print(f"Connection Exception: {e}")
        return False, str(e)

def main():
    print("=" * 60)
    print("M1 BACKEND & DATABASE VERIFICATION SUITE")
    print("=" * 60)

    results = {}

    # 1. Announcements schema (attachment_name, attachment_url)
    ok_ann, body_ann = check_endpoint(
        "Announcements Schema (attachment_name, attachment_url)",
        f"{BASE_URL}/rest/v1/announcements?select=id,title,attachment_name,attachment_url"
    )
    results["announcements_schema"] = ok_ann

    # 2. Halaqahs schema & query (including schedule column)
    ok_hal, body_hal = check_endpoint(
        "Halaqahs Schema (id, name, schedule)",
        f"{BASE_URL}/rest/v1/halaqahs?select=id,name,schedule"
    )
    results["halaqahs_schema"] = ok_hal

    # 3. Students Cloud Fetch Query (with halaqahs and parent_students joins)
    ok_stu, body_stu = check_endpoint(
        "Students Cloud Fetch Query (with halaqahs & parent_students joins)",
        f"{BASE_URL}/rest/v1/students?select=id,full_name,halaqah_id,current_juz,current_surah,current_ayah,date_of_birth,created_at,halaqahs:halaqah_id(name),parent_students(parent_id,profiles:parent_id(full_name,phone,email))"
    )
    results["students_query"] = ok_stu

    # 4. Storage Buckets Check (Asserting presence of required buckets)
    ok_buckets, body_buckets = check_endpoint(
        "Storage Buckets API (list all buckets)",
        f"{BASE_URL}/storage/v1/bucket"
    )
    
    storage_passed = False
    if ok_buckets:
        try:
            parsed_buckets = json.loads(body_buckets)
            existing_bucket_ids = {
                b.get("id") or b.get("name") for b in parsed_buckets if isinstance(b, dict)
            }
            required_buckets = [
                "announcement_attachments",
                "chat_attachments",
                "voice_messages",
            ]
            missing_buckets = [b for b in required_buckets if b not in existing_bucket_ids]
            
            print(f"Required buckets: {required_buckets}")
            print(f"Found bucket IDs: {list(existing_bucket_ids)}")
            
            if missing_buckets:
                print(f"[FAIL] Missing required storage buckets: {missing_buckets}")
                storage_passed = False
            else:
                # Also verify each individual bucket endpoint directly
                all_individual_ok = True
                for b_name in required_buckets:
                    indiv_ok, indiv_body = check_endpoint(
                        f"Storage Bucket: {b_name}",
                        f"{BASE_URL}/storage/v1/bucket/{b_name}"
                    )
                    if not indiv_ok:
                        all_individual_ok = False
                        print(f"[FAIL] Individual bucket check failed for: {b_name}")
                storage_passed = all_individual_ok
        except Exception as e:
            print(f"[FAIL] Error parsing bucket response: {e}")
            storage_passed = False
    
    results["storage_buckets"] = storage_passed

    # 5. Stored Procedures Check (generate_invitation_code RPC)
    test_gen = json.dumps({"p_role": "parent"}).encode()
    ok_rpc, gen_body = check_endpoint(
        "generate_invitation_code RPC",
        f"{BASE_URL}/rest/v1/rpc/generate_invitation_code",
        method="POST",
        data=test_gen
    )
    results["generate_invitation_code"] = ok_rpc

    print("\n" + "=" * 60)
    print("VERIFICATION SUMMARY:")
    print("=" * 60)
    all_passed = True
    for test, passed in results.items():
        status = "[PASS]" if passed else "[FAIL]"
        print(f"{test:35}: {status}")
        if not passed:
            all_passed = False

    if all_passed:
        print("\nALL VERIFICATION CHECKS PASSED SUCCESSFULLY!")
    else:
        print("\nSOME VERIFICATION CHECKS FAILED.")

    return all_passed

if __name__ == "__main__":
    passed = main()
    sys.exit(0 if passed else 1)
