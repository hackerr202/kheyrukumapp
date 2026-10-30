import json
import os
import re
import ssl
import sys
import time
import urllib.request
import urllib.error

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"
EMAIL = "challenger_test_m1@kheyrukum.com"
PASSWORD = "TestPassword123!"

def get_auth_token():
    # First check test_token.txt
    if os.path.exists("test_token.txt"):
        with open("test_token.txt", "r") as f:
            t = f.read().strip()
            if len(t) > 50:
                # Test token validity
                req = urllib.request.Request(
                    f"{BASE_URL}/auth/v1/user",
                    headers={"apikey": ANON_KEY, "Authorization": f"Bearer {t}"}
                )
                try:
                    with urllib.request.urlopen(req, timeout=10) as r:
                        if r.status == 200:
                            print(f"[AUTH] Cached JWT valid (length {len(t)})")
                            return t
                except Exception:
                    print("[AUTH] Cached JWT expired or invalid, re-authenticating...")

    # Sign in
    req = urllib.request.Request(
        f"{BASE_URL}/auth/v1/token?grant_type=password",
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
        data=json.dumps({"email": EMAIL, "password": PASSWORD}).encode()
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        token = data["access_token"]
        print(f"[AUTH] Re-authenticated successfully. New JWT length: {len(token)}")
        with open("test_token.txt", "w") as f:
            f.write(token)
        return token

def test_bucket_metadata(bucket_name):
    print(f"\n--- 1. Testing Bucket Metadata: '{bucket_name}' ---")
    url = f"{BASE_URL}/storage/v1/bucket/{bucket_name}"
    req = urllib.request.Request(url, headers={"apikey": ANON_KEY, "Authorization": f"Bearer {ANON_KEY}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            print(f"Bucket Info: id={data.get('id')}, name={data.get('name')}, public={data.get('public')}")
            assert data.get('public') is True, f"Bucket '{bucket_name}' must be marked as public!"
            print(f"[PASS] Bucket '{bucket_name}' is verified public.")
            return True
    except Exception as e:
        print(f"[FAIL] Error checking bucket '{bucket_name}': {e}")
        return False

def test_upload_and_public_download(token, bucket_name, file_prefix, file_name, file_bytes, mime_type):
    print(f"\n--- Testing Upload & Public URL for Bucket '{bucket_name}' ---")
    clean_name = re.sub(r'[^a-zA-Z0-9._-]', '_', file_name)
    timestamp = int(time.time() * 1000)
    relative_path = f"{file_prefix}/{timestamp}_{clean_name}"
    upload_url = f"{BASE_URL}/storage/v1/object/{bucket_name}/{relative_path}"

    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": mime_type,
        "x-upsert": "true",
    }

    print(f"Uploading {len(file_bytes)} bytes to: {relative_path} (MIME: {mime_type})")
    req = urllib.request.Request(upload_url, data=file_bytes, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            print(f"Upload Response: Status {resp.status} {resp.reason}")
            assert resp.status in (200, 201), f"Upload returned unexpected status {resp.status}"
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"[FAIL] Upload failed with HTTP {e.code}: {err}")
        return False, None

    # Public download WITHOUT auth headers
    public_url = f"{BASE_URL}/storage/v1/object/public/{bucket_name}/{relative_path}"
    print(f"Testing anonymous public GET: {public_url}")
    pub_req = urllib.request.Request(public_url, method="GET") # Zero auth headers!
    for attempt in range(3):
        try:
            with urllib.request.urlopen(pub_req, timeout=25) as pub_resp:
                print(f"Public Download Response: Status {pub_resp.status} {pub_resp.reason}")
                assert pub_resp.status == 200, f"Public download returned {pub_resp.status}"
                downloaded = pub_resp.read()
                assert downloaded == file_bytes, f"Downloaded content size {len(downloaded)} != uploaded size {len(file_bytes)}"
                resp_content_type = pub_resp.headers.get("Content-Type", "")
                print(f"Content-Type received: {resp_content_type}")
                print(f"[PASS] Successfully verified public URL download! Content perfectly matched ({len(downloaded)} bytes).")
                return True, public_url
        except Exception as e:
            if attempt == 2:
                print(f"[FAIL] Public download failed after 3 attempts: {e}")
                return False, None
            time.sleep(1.5)

def test_announcement_persistence(token, public_url, attachment_name):
    print("\n--- Testing Announcement Relational Persistence with Attachment ---")
    post_url = f"{BASE_URL}/rest/v1/announcements"
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    payload = {
        "title": f"M3 Challenger Test Announcement {int(time.time())}",
        "content": "This is an empirical verification test circular with an attached native file.",
        "target_audience": "all",
        "author_name": "Milestone 3 Challenger",
        "is_pinned": False,
        "attachment_url": public_url,
        "attachment_name": attachment_name,
    }

    req = urllib.request.Request(post_url, data=json.dumps(payload).encode(), headers=headers, method="POST")
    announcement_id = None
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
            print(f"Announcement Insert Response: Status {resp.status}")
            if isinstance(data, list) and len(data) > 0:
                announcement = data[0]
            else:
                announcement = data
            announcement_id = announcement.get("id")
            print(f"Created Announcement ID: {announcement_id}")
            assert announcement.get("attachment_url") == public_url, "attachment_url mismatch in database!"
            assert announcement.get("attachment_name") == attachment_name, "attachment_name mismatch in database!"
            print(f"[PASS] Announcement persisted with valid attachment_url and attachment_name!")
    except Exception as e:
        print(f"[FAIL] Error posting announcement: {e}")
        return False

    # Cleanup test record
    if announcement_id:
        del_url = f"{BASE_URL}/rest/v1/announcements?id=eq.{announcement_id}"
        del_req = urllib.request.Request(del_url, headers=headers, method="DELETE")
        try:
            with urllib.request.urlopen(del_req, timeout=10) as del_resp:
                print(f"Cleaned up test announcement ID {announcement_id}: Status {del_resp.status}")
        except Exception as e:
            print(f"Warning: Cleanup failed for {announcement_id}: {e}")

    return True

def test_codebase_integrity():
    print("\n--- Codebase & Static Assertions Audit ---")
    dialog_path = "lib/screens/announcements/post_announcement_dialog.dart"
    chat_path = "lib/screens/messages/chat_screen.dart"
    storage_path = "lib/core/services/storage_service.dart"

    # 1. Dialog checks
    with open(dialog_path, "r", encoding="utf-8") as f:
        dialog_code = f.read()

    assert "Clipboard" not in dialog_code, "Clipboard reference found in PostAnnouncementDialog!"
    assert "_pasteFromClipboard" not in dialog_code, "_pasteFromClipboard found in PostAnnouncementDialog!"
    assert "FilePicker.platform.pickFiles" in dialog_code, "FilePicker missing in PostAnnouncementDialog"
    assert "StorageService.uploadAnnouncementAttachment" in dialog_code, "StorageService upload missing in dialog"
    assert "_isUploadingAttachment" in dialog_code, "Upload loading indicator missing"
    assert "_removeAttachment" in dialog_code, "Remove attachment handler missing"
    # Ensure byte and path handling both exist
    assert "pickedFile.bytes ??" in dialog_code or "pickedFile.bytes" in dialog_code, "pickedFile.bytes must be handled"
    assert "pickedFile.path" in dialog_code, "pickedFile.path fallback must be handled"
    print("[PASS] PostAnnouncementDialog assertions all verified.")

    # 2. Chat screen checks
    with open(chat_path, "r", encoding="utf-8") as f:
        chat_code = f.read()

    assert "_showAddLinkDialog" not in chat_code, "_showAddLinkDialog still in ChatScreen!"
    assert "Paste Image URL" not in chat_code, "'Paste Image URL' still in ChatScreen!"
    assert "AudioRecorder" in chat_code, "AudioRecorder missing in ChatScreen"
    assert "AudioPlayer" in chat_code, "AudioPlayer missing in ChatScreen"
    assert "StorageService.uploadVoiceNote" in chat_code, "uploadVoiceNote missing in ChatScreen"
    assert "StorageService.uploadChatAttachment" in chat_code, "uploadChatAttachment missing in ChatScreen"
    assert "launchUrl" in chat_code, "launchUrl missing for document bubbles in ChatScreen"
    print("[PASS] ChatScreen assertions all verified.")

    # 3. StorageService checks
    with open(storage_path, "r", encoding="utf-8") as f:
        storage_code = f.read()

    assert "announcement_attachments" in storage_code
    assert "chat_attachments" in storage_code
    assert "voice_messages" in storage_code
    assert "uploadAnnouncementAttachment" in storage_code
    assert "uploadChatAttachment" in storage_code
    assert "uploadVoiceNote" in storage_code
    assert "getPublicUrl" in storage_code
    print("[PASS] StorageService assertions all verified.")
    return True

def main():
    print("=" * 70)
    print("EMPIRICAL ADVERSARIAL CHALLENGER SUITE: MILESTONE 3")
    print("=" * 70)

    token = get_auth_token()
    results = {}

    # Test Buckets
    for b in ["announcement_attachments", "chat_attachments", "voice_messages"]:
        results[f"bucket_meta_{b}"] = test_bucket_metadata(b)

    # Test Announcement Attachment Upload & Public Serving
    sample_pdf_bytes = b"%PDF-1.5 \xde\xad\xbe\xef 1 0 obj << /Title (Test Announcement Attachment) >> endobj xref 0 1 trailer << /Root 1 0 R >> %%EOF"
    pdf_filename = "Ramadan Timetable & Circular (2026).pdf"
    ok_ann, public_url = test_upload_and_public_download(
        token=token,
        bucket_name="announcement_attachments",
        file_prefix="announcements",
        file_name=pdf_filename,
        file_bytes=sample_pdf_bytes,
        mime_type="application/pdf"
    )
    results["announcement_upload_and_public_get"] = ok_ann

    # Test Announcement DB Persistence with attachment
    if ok_ann and public_url:
        results["announcement_db_persistence"] = test_announcement_persistence(token, public_url, pdf_filename)
    else:
        results["announcement_db_persistence"] = False

    # Test Chat Attachment Upload & Public Serving
    sample_png_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    ok_chat, _ = test_upload_and_public_download(
        token=token,
        bucket_name="chat_attachments",
        file_prefix="chat/conv_test_123",
        file_name="recitation_homework.png",
        file_bytes=sample_png_bytes,
        mime_type="image/png"
    )
    results["chat_upload_and_public_get"] = ok_chat

    # Test Voice Message Upload & Public Serving (AAC / M4A)
    sample_m4a_bytes = b"\x00\x00\x00 ftypM4A \x00\x00\x00\x00M4A mp42isom\x00\x00\x00\x08free\x00\x00\x00\x10mdat" + b"\x00" * 64
    ok_voice, _ = test_upload_and_public_download(
        token=token,
        bucket_name="voice_messages",
        file_prefix="voice/conv_test_123",
        file_name="surah_fatiha_recitation.m4a",
        file_bytes=sample_m4a_bytes,
        mime_type="audio/m4a"
    )
    results["voice_upload_and_public_get"] = ok_voice

    # Test Static and Codebase Integrity
    results["codebase_integrity"] = test_codebase_integrity()

    print("\n" + "=" * 70)
    print("CHALLENGER SUITE SUMMARY RESULTS")
    print("=" * 70)
    all_ok = True
    for test, passed in results.items():
        st = "[PASS]" if passed else "[FAIL]"
        print(f"{test:40}: {st}")
        if not passed:
            all_ok = False

    if all_ok:
        print("\n>>> ALL EMPIRICAL CHALLENGER TESTS PASSED! VERDICT: APPROVE <<<")
        sys.exit(0)
    else:
        print("\n>>> EMPIRICAL CHALLENGER TESTS FAILED! VERDICT: REJECT <<<")
        sys.exit(1)

if __name__ == "__main__":
    main()
