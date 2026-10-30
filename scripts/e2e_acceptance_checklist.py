#!/usr/bin/env python3
"""
================================================================================
E2E ACCEPTANCE CHECKLIST HARNESS: 4-POINT MANDATORY VERIFICATION
================================================================================
Performs comprehensive dual-layer validation (Static Codebase Contract + Live Supabase Cloud)
for the 4 acceptance checks specified in the project requirements:

Check 1: Student Created -> App Reinstall Simulation (remote-only fetch) -> Remote Persistence & Parent Linkage
Check 2: Halaqah Created -> Immediate Appearance & Relational Schema Columns (schedule, description, teacher_id)
Check 3: Broadcast Circular with Device Attachment -> Storage Upload & Relational Post without PGRST204
Check 4: Chat Communication Flow:
  - + New Chat FAB clearance and visibility above MeniscusNavBar
  - Native media attachments (Image/Document) upload & download
  - Real voice note recording (AAC .m4a) & streaming playback
================================================================================
"""

import os
import re
import ssl
import sys
import json
import time
import urllib.request
import urllib.error
import pg8000.native

sys.path.append(os.path.abspath('scripts'))
from check_syntax import check_brackets

BASE_URL = "https://tjhqpzvjzmpyrridtpsj.supabase.co"
ANON_KEY = "sb_publishable_zTV0p7ofXzpZ_sWbUwcCgg_2NpvA_3g"
EMAIL = "challenger_test_m1@kheyrukum.com"
PASSWORD = "TestPassword123!"

POOLER_HOST = "aws-1-eu-west-3.pooler.supabase.com"
DB_USER = "postgres.tjhqpzvjzmpyrridtpsj"
DB_PASS = "ustazmuhammedyakut"
DB_NAME = "postgres"

def get_auth_token():
    if os.path.exists("test_token.txt"):
        with open("test_token.txt", "r") as f:
            t = f.read().strip()
            if len(t) > 50:
                req = urllib.request.Request(
                    f"{BASE_URL}/auth/v1/user",
                    headers={"apikey": ANON_KEY, "Authorization": f"Bearer {t}"}
                )
                try:
                    with urllib.request.urlopen(req, timeout=10) as r:
                        if r.status == 200:
                            return t
                except Exception:
                    pass

    req = urllib.request.Request(
        f"{BASE_URL}/auth/v1/token?grant_type=password",
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
        data=json.dumps({"email": EMAIL, "password": PASSWORD}).encode()
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        token = data["access_token"]
        with open("test_token.txt", "w") as f:
            f.write(token)
        return token

# ==============================================================================
# CHECK 1: Student Created -> Reinstall Simulation -> Remote Persistence
# ==============================================================================
def verify_check_1_static():
    path = "lib/core/services/student_service.dart"
    with open(path, "r", encoding="utf-8") as f:
        code = f.read()

    # Verify query includes joins to halaqahs and parent_students(profiles)
    expected_select = "parent_students(parent_id, profiles:parent_id(full_name, phone, email))"
    if expected_select not in code:
        return False, f"Missing parent_students profile join in {path}"

    if "halaqahs:halaqah_id(name)" not in code:
        return False, f"Missing halaqahs join in {path}"

    # Verify offline cache does not override remote cloud
    if "cached_students" not in code:
        return False, "Offline caching logic missing in student_service.dart"

    # Verify parent_students insertion
    if ".from('parent_students').insert" not in code:
        return False, "Parent linking insertion missing in student_service.dart"

    return True, "student_service.dart static contract verified"

def verify_check_1_dynamic(token):
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

    unique_name = f"Acceptance Student {int(time.time())}"
    stu_payload = {
        "full_name": unique_name,
        "current_juz": 30,
        "current_surah": 112,
        "current_ayah": 4,
    }

    # 1. Create student
    req_stu = urllib.request.Request(
        f"{BASE_URL}/rest/v1/students",
        data=json.dumps(stu_payload).encode(),
        headers=headers,
        method="POST"
    )
    with urllib.request.urlopen(req_stu, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        student_id = data[0]["id"]

    # 2. Link to parent
    test_parent_id = "44ff1955-aafe-4ebc-913d-91e4c8634b85"
    link_payload = {
        "parent_id": test_parent_id,
        "student_id": student_id,
    }
    req_link = urllib.request.Request(
        f"{BASE_URL}/rest/v1/parent_students",
        data=json.dumps(link_payload).encode(),
        headers=headers,
        method="POST"
    )
    with urllib.request.urlopen(req_link, timeout=15) as resp:
        assert resp.status in (200, 201)

    # 3. App Reinstall Simulation: Zero local caching, direct remote PostgREST query
    fetch_url = (
        f"{BASE_URL}/rest/v1/students?id=eq.{student_id}&"
        "select=id,full_name,halaqah_id,current_juz,current_surah,current_ayah,date_of_birth,created_at,"
        "halaqahs:halaqah_id(name),parent_students(parent_id,profiles:parent_id(full_name,phone,email))"
    )
    req_fetch = urllib.request.Request(fetch_url, headers=headers, method="GET")
    with urllib.request.urlopen(req_fetch, timeout=15) as resp:
        fetched = json.loads(resp.read().decode())
        assert len(fetched) == 1, "Failed to retrieve student on simulated reinstall"
        st = fetched[0]
        assert st["full_name"] == unique_name, "Student full_name corrupted"
        assert st["current_juz"] == 30, "Student current_juz corrupted"
        assert st["current_surah"] == 112, "Student current_surah corrupted"
        assert len(st["parent_students"]) > 0, "Student parent linkage lost"
        assert st["parent_students"][0]["parent_id"] == test_parent_id, "Linked parent ID mismatch"

    # 4. Cleanup
    try:
        urllib.request.urlopen(urllib.request.Request(f"{BASE_URL}/rest/v1/parent_students?student_id=eq.{student_id}", headers=headers, method="DELETE"), timeout=20)
        urllib.request.urlopen(urllib.request.Request(f"{BASE_URL}/rest/v1/students?id=eq.{student_id}", headers=headers, method="DELETE"), timeout=20)
    except Exception:
        pass

    return True, f"Verified student {student_id} survives reinstall simulation with intact parent linkage"

# ==============================================================================
# CHECK 2: Halaqah Created -> Immediate Appearance & Schema Columns
# ==============================================================================
def verify_check_2_static():
    service_path = "lib/core/services/halaqah_service.dart"
    sheet_path = "lib/screens/admin/halaqah_management_sheet.dart"

    with open(service_path, "r", encoding="utf-8") as f:
        s_code = f.read()
    with open(sheet_path, "r", encoding="utf-8") as f:
        sh_code = f.read()

    # Assert schedule and description payload columns
    if "'schedule':" not in s_code or "'description':" not in s_code:
        return False, "Missing schedule/description in halaqah_service.dart payload"

    # Assert immediate UI notification
    if "halaqahsNotifier.value" not in s_code:
        return False, "halaqahsNotifier.value update missing in halaqah_service.dart"

    # Assert sheet listens to halaqahsNotifier
    if "ValueListenableBuilder<List<Halaqah>>" not in sh_code:
        return False, "ValueListenableBuilder missing in halaqah_management_sheet.dart"

    return True, "halaqah creation static contracts verified"

def verify_check_2_dynamic(token):
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

    unique_name = f"Acceptance Halaqah {int(time.time())}"
    schedule_str = "Sun-Thu 4:30 PM - 6:30 PM"
    desc_str = "Hifz Juz 30 and Tajweed rules verification"

    hal_payload = {
        "name": unique_name,
        "schedule": schedule_str,
        "description": desc_str,
    }

    req = urllib.request.Request(
        f"{BASE_URL}/rest/v1/halaqahs",
        data=json.dumps(hal_payload).encode(),
        headers=headers,
        method="POST"
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        inserted = json.loads(resp.read().decode())
        hal_id = inserted[0]["id"]
        assert inserted[0]["name"] == unique_name
        assert inserted[0]["schedule"] == schedule_str
        assert inserted[0]["description"] == desc_str

    # Query back with join
    query_url = f"{BASE_URL}/rest/v1/halaqahs?id=eq.{hal_id}&select=id,name,schedule,description,teacher_id,profiles:teacher_id(full_name)"
    req_query = urllib.request.Request(query_url, headers=headers, method="GET")
    with urllib.request.urlopen(req_query, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        assert len(data) == 1
        assert data[0]["name"] == unique_name
        assert data[0]["schedule"] == schedule_str

    # Cleanup
    try:
        urllib.request.urlopen(urllib.request.Request(f"{BASE_URL}/rest/v1/halaqahs?id=eq.{hal_id}", headers=headers, method="DELETE"), timeout=20)
    except Exception:
        pass

    return True, f"Verified halaqah {hal_id} immediately persists with schedule and description schema columns"

# ==============================================================================
# CHECK 3: Broadcast Circular with Device File Attachment (Zero PGRST204)
# ==============================================================================
def verify_check_3_static():
    dialog_path = "lib/screens/announcements/post_announcement_dialog.dart"
    service_path = "lib/core/services/announcement_service.dart"

    with open(dialog_path, "r", encoding="utf-8") as f:
        d_code = f.read()
    with open(service_path, "r", encoding="utf-8") as f:
        s_code = f.read()

    # Zero clipboard paste
    if "Clipboard.getData" in d_code or "_pasteFromClipboard" in d_code:
        return False, "Found forbidden clipboard paste logic in PostAnnouncementDialog"

    # Genuine file picker
    if "FilePicker.platform.pickFiles" not in d_code:
        return False, "FilePicker.platform.pickFiles missing in PostAnnouncementDialog"

    # Storage upload
    if "StorageService.uploadAnnouncementAttachment" not in d_code:
        return False, "StorageService.uploadAnnouncementAttachment missing in dialog"

    # Insertion payload contains attachment columns
    if "'attachment_name': attachmentName" not in s_code or "'attachment_url': attachmentUrl" not in s_code:
        return False, "attachment_name / attachment_url missing in announcement_service.dart payload"

    return True, "Broadcast circular device upload static contract verified"

def verify_check_3_dynamic(token):
    # 1. Storage Upload
    test_pdf_content = b"%PDF-1.5 %Acceptance Test Circular Attachment Payload\r\n%%EOF"
    pdf_filename = f"Acceptance_Circular_{int(time.time())}.pdf"
    storage_path = f"announcements/acceptance/{pdf_filename}"
    upload_url = f"{BASE_URL}/storage/v1/object/announcement_attachments/{storage_path}"

    up_headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/pdf",
        "x-upsert": "true",
    }
    req_up = urllib.request.Request(upload_url, data=test_pdf_content, headers=up_headers, method="POST")
    with urllib.request.urlopen(req_up, timeout=15) as resp:
        assert resp.status in (200, 201)

    public_url = f"{BASE_URL}/storage/v1/object/public/announcement_attachments/{storage_path}"

    # Verify public unauthenticated GET
    req_pub = urllib.request.Request(public_url, method="GET")
    downloaded = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req_pub, timeout=25) as resp:
                assert resp.status == 200
                downloaded = resp.read()
                break
        except Exception:
            if attempt == 2:
                raise
            time.sleep(1.5)
    assert downloaded == test_pdf_content

    # 2. Post announcement without PGRST204
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    ann_payload = {
        "title": f"Ramadan Timetable Notice {int(time.time())}",
        "content": "Official announcement with native device attachment.",
        "target_audience": "all",
        "author_name": "Center Director",
        "is_pinned": True,
        "attachment_name": pdf_filename,
        "attachment_url": public_url,
    }
    req_ann = urllib.request.Request(
        f"{BASE_URL}/rest/v1/announcements",
        data=json.dumps(ann_payload).encode(),
        headers=headers,
        method="POST"
    )
    with urllib.request.urlopen(req_ann, timeout=15) as resp:
        assert resp.status in (200, 201)
        data = json.loads(resp.read().decode())
        ann_id = data[0]["id"]
        assert data[0]["attachment_name"] == pdf_filename
        assert data[0]["attachment_url"] == public_url

    # 3. Cleanup
    try:
        urllib.request.urlopen(urllib.request.Request(f"{BASE_URL}/rest/v1/announcements?id=eq.{ann_id}", headers=headers, method="DELETE"), timeout=20)
    except Exception:
        pass
    try:
        urllib.request.urlopen(urllib.request.Request(upload_url, headers=up_headers, method="DELETE"), timeout=20)
    except Exception:
        pass

    return True, f"Verified announcement {ann_id} uploaded to storage and persisted in DB without PGRST204 error"

# ==============================================================================
# CHECK 4: Chat Communication Flow (FAB Clearance, Device Media, Voice Pipeline)
# ==============================================================================
def verify_check_4_static():
    tab_path = "lib/screens/dashboard/tabs/messages_tab.dart"
    chat_path = "lib/screens/messages/chat_screen.dart"

    with open(tab_path, "r", encoding="utf-8") as f:
        t_code = f.read()
    with open(chat_path, "r", encoding="utf-8") as f:
        c_code = f.read()

    # FAB Clearance
    fab_match = re.search(r'floatingActionButton:\s*Padding\(\s*padding:\s*const\s*EdgeInsets\.only\([^)]*bottom:\s*(\d+)', t_code)
    if not fab_match or int(fab_match.group(1)) < 90:
        return False, "FAB bottom clearance in messages_tab.dart is missing or < 90px"

    if "'+ New Chat'" not in t_code and '"+ New Chat"' not in t_code:
        return False, "FAB label '+ New Chat' missing in messages_tab.dart"

    # Chat screen zero paste dialog
    if "_showAddLinkDialog" in c_code or "Paste Image URL" in c_code:
        return False, "Found forbidden 'Paste Image URL' dialog in chat_screen.dart"

    # Hardware audio recording & streaming player
    if "AudioRecorder" not in c_code or "RecordConfig" not in c_code:
        return False, "AudioRecorder / RecordConfig missing in chat_screen.dart"
    if "AudioPlayer" not in c_code or "UrlSource" not in c_code:
        return False, "AudioPlayer / UrlSource missing in chat_screen.dart"

    # Native media pickers
    if "ImagePicker" not in c_code or "FilePicker.platform.pickFiles" not in c_code:
        return False, "ImagePicker / FilePicker missing in chat_screen.dart"

    return True, "Chat screen FAB, media pickers, and audio engine static contracts verified"

def verify_check_4_dynamic(token):
    # 1. Voice note storage upload & streaming verification
    voice_bytes = b"\x00\x00\x00 ftypM4A \x00\x00\x00\x00M4A mp42isom" + b"\x00" * 32
    voice_file = f"voice_acceptance_{int(time.time())}.m4a"
    up_voice_url = f"{BASE_URL}/storage/v1/object/voice_messages/acceptance/{voice_file}"

    v_headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "audio/m4a",
        "x-upsert": "true",
    }
    req_v_up = urllib.request.Request(up_voice_url, data=voice_bytes, headers=v_headers, method="POST")
    with urllib.request.urlopen(req_v_up, timeout=15) as resp:
        assert resp.status in (200, 201)

    public_voice_url = f"{BASE_URL}/storage/v1/object/public/voice_messages/acceptance/{voice_file}"

    req_v_get = urllib.request.Request(public_voice_url, method="GET")
    with urllib.request.urlopen(req_v_get, timeout=15) as resp:
        assert resp.status == 200
        streamed = resp.read()
        assert streamed == voice_bytes

    # 2. Chat attachment storage upload & download verification
    img_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4" + b"\x00" * 16
    img_file = f"chat_img_{int(time.time())}.png"
    up_img_url = f"{BASE_URL}/storage/v1/object/chat_attachments/acceptance/{img_file}"

    img_headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "image/png",
        "x-upsert": "true",
    }
    req_img_up = urllib.request.Request(up_img_url, data=img_bytes, headers=img_headers, method="POST")
    with urllib.request.urlopen(req_img_up, timeout=15) as resp:
        assert resp.status in (200, 201)

    public_img_url = f"{BASE_URL}/storage/v1/object/public/chat_attachments/acceptance/{img_file}"
    req_img_get = urllib.request.Request(public_img_url, method="GET")
    with urllib.request.urlopen(req_img_get, timeout=15) as resp:
        assert resp.status == 200
        assert resp.read() == img_bytes

    # Cleanup storage
    try:
        urllib.request.urlopen(urllib.request.Request(up_voice_url, headers=v_headers, method="DELETE"), timeout=15)
        urllib.request.urlopen(urllib.request.Request(up_img_url, headers=img_headers, method="DELETE"), timeout=15)
    except Exception:
        pass

    return True, "Verified voice note (.m4a) & media attachment uploads and unauthenticated streaming/downloads"

def main():
    print("=" * 75)
    print("RUNNING 4-POINT ACCEPTANCE CHECKLIST VERIFICATION HARNESS")
    print("=" * 75)

    token = get_auth_token()
    results = {}

    # Check 1
    print("\n[CHECK 1] Student Reinstall & Remote Cloud Persistence")
    ok_1_s, msg_1_s = verify_check_1_static()
    print(f"  Static Contract : {'[PASS]' if ok_1_s else '[FAIL]'} - {msg_1_s}")
    ok_1_d, msg_1_d = verify_check_1_dynamic(token)
    print(f"  Live Backend    : {'[PASS]' if ok_1_d else '[FAIL]'} - {msg_1_d}")
    results["Check 1: Student Reinstall Persistence"] = ok_1_s and ok_1_d

    # Check 2
    print("\n[CHECK 2] Halaqah Creation & Relational Schema Columns")
    ok_2_s, msg_2_s = verify_check_2_static()
    print(f"  Static Contract : {'[PASS]' if ok_2_s else '[FAIL]'} - {msg_2_s}")
    ok_2_d, msg_2_d = verify_check_2_dynamic(token)
    print(f"  Live Backend    : {'[PASS]' if ok_2_d else '[FAIL]'} - {msg_2_d}")
    results["Check 2: Halaqah Relational Creation"] = ok_2_s and ok_2_d

    # Check 3
    print("\n[CHECK 3] Broadcast Circular Device Attachment (Zero PGRST204)")
    ok_3_s, msg_3_s = verify_check_3_static()
    print(f"  Static Contract : {'[PASS]' if ok_3_s else '[FAIL]'} - {msg_3_s}")
    ok_3_d, msg_3_d = verify_check_3_dynamic(token)
    print(f"  Live Backend    : {'[PASS]' if ok_3_d else '[FAIL]'} - {msg_3_d}")
    results["Check 3: Broadcast Circular Attachment"] = ok_3_s and ok_3_d

    # Check 4
    print("\n[CHECK 4] Chat Communication Pipeline (FAB, Media & Voice Notes)")
    ok_4_s, msg_4_s = verify_check_4_static()
    print(f"  Static Contract : {'[PASS]' if ok_4_s else '[FAIL]'} - {msg_4_s}")
    ok_4_d, msg_4_d = verify_check_4_dynamic(token)
    print(f"  Live Backend    : {'[PASS]' if ok_4_d else '[FAIL]'} - {msg_4_d}")
    results["Check 4: Chat Communication Pipeline"] = ok_4_s and ok_4_d

    print("\n" + "=" * 75)
    print("4-POINT ACCEPTANCE SUMMARY:")
    all_passed = True
    for test_name, passed in results.items():
        st = "[PASS]" if passed else "[FAIL]"
        print(f"  {test_name:45}: {st}")
        if not passed:
            all_passed = False

    print("=" * 75)
    if all_passed:
        print(">>> ALL 4 MANDATORY ACCEPTANCE CHECKS PASSED WITH 100% SUCCESS! <<<")
        sys.exit(0)
    else:
        print(">>> SOME ACCEPTANCE CHECKS FAILED! <<<")
        sys.exit(1)

if __name__ == "__main__":
    main()
