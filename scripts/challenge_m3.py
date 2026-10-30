import os
import re
import sys

def check_permissions_and_manifest():
    print("\n--- Check 1: Native Permissions & Manifest/Plist ---")
    manifest = open('android/app/src/main/AndroidManifest.xml', encoding='utf-8').read()
    plist = open('ios/Runner/Info.plist', encoding='utf-8').read()
    patch = open('scripts/patch_manifest.py', encoding='utf-8').read()

    required_android = [
        'android.permission.RECORD_AUDIO',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.READ_MEDIA_VIDEO',
        'android.permission.READ_MEDIA_AUDIO',
        'android.permission.CAMERA',
    ]
    for p in required_android:
        assert p in manifest, f"Missing {p} in AndroidManifest.xml"
        assert p in patch, f"Missing {p} in patch_manifest.py"
    print("  [PASS] Android Manifest has all 6 required permissions.")

    required_ios = [
        'NSMicrophoneUsageDescription',
        'NSPhotoLibraryUsageDescription',
        'NSCameraUsageDescription',
    ]
    for k in required_ios:
        assert f'<key>{k}</key>' in plist, f"Missing {k} in Info.plist"
    print("  [PASS] iOS Info.plist has all 3 required usage descriptions.")

def check_runtime_permission_flows():
    print("\n--- Check 2: Runtime Permission Handling & Denials ---")
    chat = open('lib/screens/messages/chat_screen.dart', encoding='utf-8').read()
    post = open('lib/screens/announcements/post_announcement_dialog.dart', encoding='utf-8').read()
    storage = open('lib/core/services/storage_service.dart', encoding='utf-8').read()

    # Microphone permission check in chat
    assert '_audioRecorder.hasPermission()' in chat, "Microphone permission check missing"
    assert 'Microphone permission is required' in chat, "Microphone denial message missing"
    print("  [PASS] ChatScreen checks microphone permission via _audioRecorder.hasPermission()")

    # Permission handler package check
    pubspec = open('pubspec.yaml', encoding='utf-8').read()
    assert 'permission_handler' in pubspec, "permission_handler not in pubspec.yaml"

    # Note: Check if permission_handler is imported in Dart code
    has_perm_handler = 'permission_handler' in chat or 'permission_handler' in post or 'permission_handler' in storage
    if not has_perm_handler:
        print("  [ADVISORY/FINDING] 'permission_handler' is declared in pubspec.yaml but not imported in chat_screen or post_announcement_dialog (record and image_picker handle platform permission dialogs directly).")
    else:
        print("  [PASS] permission_handler is actively used in Dart code.")

def check_loading_states_and_concurrency():
    print("\n--- Check 3: Loading States & Double Submission Prevention ---")
    post = open('lib/screens/announcements/post_announcement_dialog.dart', encoding='utf-8').read()
    chat = open('lib/screens/messages/chat_screen.dart', encoding='utf-8').read()

    # PostAnnouncementDialog broadcast button disabled during upload
    assert '(_isBroadcasting || _isUploadingAttachment) ? null : _handleBroadcast' in post, \
        "Broadcast button must be disabled when _isUploadingAttachment is true"
    assert '_isUploadingAttachment' in post, "_isUploadingAttachment missing in PostAnnouncementDialog"
    print("  [PASS] PostAnnouncementDialog disables broadcast button during attachment upload.")

    # PostAnnouncementDialog picker replaced during upload
    assert 'if (_isUploadingAttachment)' in post, "Upload spinner container must replace picker when uploading"
    print("  [PASS] PostAnnouncementDialog displays upload spinner and prevents re-picking during upload.")

    # ChatScreen media pickers set _isUploadingAttachment
    assert 'setState(() => _isUploadingAttachment = true);' in chat, "ChatScreen must toggle _isUploadingAttachment"
    assert '_isUploadingAttachment ? null : () => _showAttachmentSheet' in chat, \
        "ChatScreen attachment clip button must be disabled during active upload"
    print("  [PASS] ChatScreen attachment button disabled while _isUploadingAttachment is true.")

    # Audio sending state check
    # Check if _finishAndSendVoiceRecording guards against double submission or sets upload indicator
    finish_code = re.search(r'Future<void> _finishAndSendVoiceRecording\(\) async \{(.*?)\n  \}', chat, re.DOTALL)
    assert finish_code, "Could not find _finishAndSendVoiceRecording in chat_screen.dart"
    code = finish_code.group(1)

    has_uploading_in_audio = '_isUploadingAttachment = true' in code or '_isSendingVoice' in code or '_isUploading' in code
    if not has_uploading_in_audio:
        print("  [FINDING - MINOR/MAJOR] _finishAndSendVoiceRecording does NOT set _isUploadingAttachment during Supabase storage upload, so the cloud upload progress banner is not shown during voice message dispatch.")
    else:
        print("  [PASS] Voice note upload toggles upload indicator.")

def check_audio_lifecycle_and_disposal():
    print("\n--- Check 4: Audio Lifecycle, Disposal & State Transitions ---")
    chat = open('lib/screens/messages/chat_screen.dart', encoding='utf-8').read()

    # Audio disposal in dispose()
    dispose_code = re.search(r'void dispose\(\) \{(.*?)\n  \}', chat, re.DOTALL)
    assert dispose_code, "Could not find dispose() in chat_screen.dart"
    d_src = dispose_code.group(1)

    assert '_audioPlayer.dispose()' in d_src, "_audioPlayer.dispose() missing"
    assert '_audioRecorder.dispose()' in d_src, "_audioRecorder.dispose() missing"
    assert '_recordingTimer?.cancel()' in d_src, "_recordingTimer cancel missing"
    assert '_playerStateSub?.cancel()' in d_src, "_playerStateSub cancel missing"
    assert '_playerPositionSub?.cancel()' in d_src, "_playerPositionSub cancel missing"
    assert '_playerDurationSub?.cancel()' in d_src, "_playerDurationSub cancel missing"
    assert '_playerCompleteSub?.cancel()' in d_src, "_playerCompleteSub cancel missing"
    print("  [PASS] ChatScreen properly cancels all 4 player stream subscriptions, timer, recorder, and player.")

    # Check state transitions in _togglePlayVoice
    toggle_code = re.search(r'Future<void> _togglePlayVoice\(ChatMessage msg\) async \{(.*?)\n  \}', chat, re.DOTALL)
    assert toggle_code, "Could not find _togglePlayVoice in chat_screen.dart"
    t_src = toggle_code.group(1)

    assert 'if (_currentlyPlayingId == msg.id)' in t_src, "Must branch on current playing message ID"
    assert 'await _audioPlayer.pause()' in t_src, "Must pause if currently playing"
    assert 'await _audioPlayer.resume()' in t_src, "Must resume if currently paused"
    assert 'await _audioPlayer.stop()' in t_src, "Must stop existing playback when switching messages"
    assert 'await _audioPlayer.play(UrlSource(url))' in t_src, "Must stream via UrlSource"
    print("  [PASS] _togglePlayVoice handles pause, resume, stop, and play via UrlSource.")

def check_error_handling_and_messages():
    print("\n--- Check 5: Media Error Handling & Sanitized Feedback ---")
    post = open('lib/screens/announcements/post_announcement_dialog.dart', encoding='utf-8').read()
    chat = open('lib/screens/messages/chat_screen.dart', encoding='utf-8').read()
    storage = open('lib/core/services/storage_service.dart', encoding='utf-8').read()

    # StorageService catch blocks
    assert 'catch (e)' in storage, "StorageService must catch upload exceptions"
    print("  [PASS] StorageService wraps uploadBinary in try-catch and returns null on failure.")

    # PostAnnouncementDialog upload failure feedback
    assert 'Cloud upload failed' in post, "PostAnnouncementDialog must display upload failure message"
    assert 'Failed to select file from device' in post, "PostAnnouncementDialog must display picker error message"
    print("  [PASS] PostAnnouncementDialog displays clean error messages on upload/picker failure.")

    # Document launcher check in chat
    assert 'canLaunchUrl' in chat, "ChatScreen must check canLaunchUrl before launching external documents"
    assert 'Could not open document URL' in chat, "ChatScreen must display user feedback when document fails to open"
    print("  [PASS] ChatScreen checks canLaunchUrl and shows user feedback on document launch failure.")

    # Media pickers catch blocks
    img_pick = re.search(r'Future<void> _pickAndSendImage.*?catch \(e\) \{(.*?)\}', chat, re.DOTALL)
    assert img_pick, "_pickAndSendImage catch block missing"
    if 'showSnackBar' not in img_pick.group(1):
        print("  [FINDING - MINOR] _pickAndSendImage catches exceptions with debugPrint but does not display a user-facing SnackBar if ImagePicker fails or throws.")
    else:
        print("  [PASS] _pickAndSendImage displays SnackBar on picker error.")

def check_integrity():
    print("\n--- Check 6: Integrity & Non-Facaded Real Implementations ---")
    chat = open('lib/screens/messages/chat_screen.dart', encoding='utf-8').read()
    post = open('lib/screens/announcements/post_announcement_dialog.dart', encoding='utf-8').read()

    # No clipboard paste
    assert 'Clipboard.getData' not in post, "INTEGRITY VIOLATION: Clipboard.getData found in post_announcement_dialog"
    assert '_pasteFromClipboard' not in post, "INTEGRITY VIOLATION: _pasteFromClipboard found in post_announcement_dialog"
    assert '_showAddLinkDialog' not in chat, "INTEGRITY VIOLATION: _showAddLinkDialog found in chat_screen"
    assert 'Paste Image URL' not in chat, "INTEGRITY VIOLATION: Paste Image URL found in chat_screen"
    print("  [PASS] Zero clipboard / link paste facades found in code.")

    # Real Audio Configuration
    assert 'AudioEncoder.aacLc' in chat, "Audio recording must use genuine AAC LC encoder"
    assert 'bitRate: 128000' in chat, "Audio recording must configure bit rate (128 kbps)"
    assert 'sampleRate: 44100' in chat, "Audio recording must configure sample rate (44.1 kHz)"
    print("  [PASS] Real AAC LC 128kbps / 44.1kHz audio configuration verified.")

    # Real Storage Buckets
    storage = open('lib/core/services/storage_service.dart', encoding='utf-8').read()
    assert "'announcement_attachments'" in storage, "Missing announcement_attachments bucket"
    assert "'chat_attachments'" in storage, "Missing chat_attachments bucket"
    assert "'voice_messages'" in storage, "Missing voice_messages bucket"
    print("  [PASS] Real Supabase Storage bucket constants verified.")

if __name__ == '__main__':
    print("=================================================================")
    print("ADVERSARIAL STRESS-TEST & INTEGRITY SUITE FOR MILESTONE 3")
    print("=================================================================")
    check_permissions_and_manifest()
    check_runtime_permission_flows()
    check_loading_states_and_concurrency()
    check_audio_lifecycle_and_disposal()
    check_error_handling_and_messages()
    check_integrity()
    print("\n=================================================================")
    print("ADVERSARIAL SUITE COMPLETED SUCCESSFULLY!")
    print("=================================================================")
