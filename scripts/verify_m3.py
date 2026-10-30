import os
import re
import sys
from check_syntax import check_brackets

def verify_pubspec():
    path = 'pubspec.yaml'
    if not os.path.exists(path):
        return False, f"File missing: {path}"
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    required_packages = [
        'permission_handler',
        'file_picker',
        'image_picker',
        'record',
        'audioplayers',
        'path_provider',
        'mime',
    ]

    missing = []
    for pkg in required_packages:
        if not re.search(rf'^\s+{re.escape(pkg)}:\s*', content, re.MULTILINE):
            missing.append(pkg)

    if missing:
        return False, f"Missing packages in pubspec.yaml: {missing}"

    return True, f"All {len(required_packages)} media & device packages verified in pubspec.yaml"

def verify_manifest():
    script_path = 'scripts/patch_manifest.py'
    manifest_path = 'android/app/src/main/AndroidManifest.xml'

    if not os.path.exists(script_path):
        return False, f"File missing: {script_path}"
    if not os.path.exists(manifest_path):
        return False, f"File missing: {manifest_path}"

    with open(script_path, 'r', encoding='utf-8') as f:
        script_content = f.read()

    with open(manifest_path, 'r', encoding='utf-8') as f:
        manifest_content = f.read()

    required_permissions = [
        'android.permission.RECORD_AUDIO',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.READ_MEDIA_VIDEO',
        'android.permission.READ_MEDIA_AUDIO',
        'android.permission.CAMERA',
    ]

    missing_in_script = [p for p in required_permissions if p not in script_content]
    if missing_in_script:
        return False, f"Permissions missing in scripts/patch_manifest.py: {missing_in_script}"

    missing_in_manifest = [p for p in required_permissions if p not in manifest_content]
    if missing_in_manifest:
        return False, f"Permissions missing in AndroidManifest.xml: {missing_in_manifest}"

    return True, f"All {len(required_permissions)} Android audio/media/storage permissions declared in patch script and manifest"

def verify_ios_plist():
    path = 'ios/Runner/Info.plist'
    if not os.path.exists(path):
        return False, f"File missing: {path}"

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    required_keys = [
        'NSMicrophoneUsageDescription',
        'NSPhotoLibraryUsageDescription',
        'NSCameraUsageDescription',
    ]

    missing = []
    for key in required_keys:
        if f'<key>{key}</key>' not in content:
            missing.append(key)

    if missing:
        return False, f"Missing Apple privacy keys in Info.plist: {missing}"

    return True, f"All {len(required_keys)} mandatory iOS privacy keys declared in Info.plist"

def verify_storage_service():
    path = 'lib/core/services/storage_service.dart'
    if not os.path.exists(path):
        return False, f"File missing: {path}"

    errs = check_brackets(path)
    if errs:
        return False, f"Syntax errors in {path}: {errs}"

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    required_methods = [
        'uploadFile',
        'getPublicUrl',
        'announcementAttachmentsBucket',
        'chatAttachmentsBucket',
        'voiceMessagesBucket',
        'uploadAnnouncementAttachment',
        'uploadChatAttachment',
        'uploadVoiceNote',
    ]

    missing = [m for m in required_methods if m not in content]
    if missing:
        return False, f"Missing methods/constants in StorageService: {missing}"

    return True, "StorageService verified with Supabase storage upload methods and bucket constants"

def verify_post_announcement_dialog():
    path = 'lib/screens/announcements/post_announcement_dialog.dart'
    if not os.path.exists(path):
        return False, f"File missing: {path}"

    errs = check_brackets(path)
    if errs:
        return False, f"Syntax errors in {path}: {errs}"

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Zero clipboard paste
    if 'Clipboard.getData' in content or '_pasteFromClipboard' in content:
        return False, "Found clipboard paste logic in PostAnnouncementDialog"

    # 2. File picker present
    if 'FilePicker.platform.pickFiles' not in content:
        return False, "FilePicker.platform.pickFiles not found in PostAnnouncementDialog"

    # 3. StorageService upload present
    if 'StorageService.uploadAnnouncementAttachment' not in content and 'StorageService.uploadFile' not in content:
        return False, "StorageService upload not called in PostAnnouncementDialog"

    # 4. Upload loading indicator state
    if '_isUploadingAttachment' not in content:
        return False, "Upload loading indicator state _isUploadingAttachment not found"

    # 5. Remove attachment option
    if '_removeAttachment' not in content:
        return False, "Remove attachment handler _removeAttachment not found"

    return True, "PostAnnouncementDialog verified (real device picker, Supabase upload, upload spinner, zero clipboard paste)"

def verify_chat_screen():
    path = 'lib/screens/messages/chat_screen.dart'
    if not os.path.exists(path):
        return False, f"File missing: {path}"

    errs = check_brackets(path)
    if errs:
        return False, f"Syntax errors in {path}: {errs}"

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Zero "Paste Image URL" dialog
    if '_showAddLinkDialog' in content:
        return False, "_showAddLinkDialog is still present in chat_screen.dart"
    if 'Paste Image URL' in content:
        return False, "'Paste Image URL' string still found in chat_screen.dart"

    # 2. Audio recorder integration
    if 'AudioRecorder' not in content:
        return False, "AudioRecorder from record package not found in ChatScreen"
    if 'RecordConfig' not in content:
        return False, "RecordConfig (AAC LC) not found in ChatScreen"
    if '_audioRecorder.start' not in content or '_audioRecorder.stop' not in content:
        return False, "Real AudioRecorder start/stop calls not found"

    # 3. Audio player integration
    if 'AudioPlayer' not in content:
        return False, "AudioPlayer from audioplayers package not found in ChatScreen"
    if 'onPlayerStateChanged' not in content or 'onPositionChanged' not in content:
        return False, "AudioPlayer state/position stream listeners not found"
    if 'UrlSource' not in content:
        return False, "UrlSource for audio streaming not found"

    # 4. Storage upload for voice notes and attachments
    if 'StorageService.uploadVoiceNote' not in content:
        return False, "StorageService.uploadVoiceNote not found in ChatScreen"
    if 'StorageService.uploadChatAttachment' not in content:
        return False, "StorageService.uploadChatAttachment not found in ChatScreen"

    # 5. Native media pickers
    if 'ImagePicker' not in content:
        return False, "ImagePicker not found in ChatScreen"
    if 'FilePicker.platform.pickFiles' not in content:
        return False, "FilePicker not found in ChatScreen"

    # 6. Clickable document bubble via url_launcher
    if 'launchUrl' not in content:
        return False, "launchUrl not found for opening documents in ChatScreen"

    return True, "ChatScreen verified (real AudioRecorder, streaming AudioPlayer, device pickers, clickable documents, zero paste dialogs)"

def main():
    print("=" * 65)
    print("M3 NATIVE DEVICE MEDIA, FILE UPLOAD & AUDIO VERIFICATION SUITE")
    print("=" * 65)

    checks = [
        ("pubspec.yaml Dependencies", verify_pubspec),
        ("Android Manifest & Patch Script", verify_manifest),
        ("iOS Info.plist Privacy Keys", verify_ios_plist),
        ("StorageService Implementation", verify_storage_service),
        ("PostAnnouncementDialog (Device Pick & Upload)", verify_post_announcement_dialog),
        ("ChatScreen (Native Media & Audio Pipeline)", verify_chat_screen),
    ]

    all_passed = True
    for name, fn in checks:
        passed, msg = fn()
        status = "[PASS]" if passed else "[FAIL]"
        print(f"{status} {name}: {msg}")
        if not passed:
            all_passed = False

    print("\n" + "=" * 65)
    if all_passed:
        print("ALL M3 VERIFICATION CHECKS PASSED SUCCESSFULLY!")
        print("=" * 65)
        sys.exit(0)
    else:
        print("SOME M3 VERIFICATION CHECKS FAILED.")
        print("=" * 65)
        sys.exit(1)

if __name__ == '__main__':
    main()
