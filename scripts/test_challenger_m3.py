import os
import sys
import re

def check_brackets(file_path):
    pairs = {'(': ')', '[': ']', '{': '}'}
    openers = pairs.keys()
    closers = pairs.values()
    stack = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    in_multiline_comment = False
    for line_num, line in enumerate(lines, 1):
        i = 0
        n = len(line)
        while i < n:
            if in_multiline_comment:
                if i + 1 < n and line[i:i+2] == '*/':
                    in_multiline_comment = False
                    i += 2
                else:
                    i += 1
                continue
                
            if i + 1 < n and line[i:i+2] == '/*':
                in_multiline_comment = True
                i += 2
                continue
                
            if i + 1 < n and line[i:i+2] == '//':
                break
                
            ch = line[i]
            
            if ch in ["'", '"']:
                quote = ch
                i += 1
                while i < n:
                    if line[i] == '\\':
                        i += 2
                    elif line[i] == quote:
                        i += 1
                        break
                    else:
                        i += 1
                continue
                
            if ch in openers:
                stack.append((ch, line_num))
            elif ch in closers:
                if not stack:
                    return f"Extra closing bracket '{ch}' at line {line_num}"
                last_ch, last_line = stack.pop()
                if pairs[last_ch] != ch:
                    return f"Mismatched bracket '{last_ch}' (line {last_line}) vs '{ch}' (line {line_num})"
            i += 1
            
    if stack:
        last_ch, last_line = stack[-1]
        return f"Unclosed bracket '{last_ch}' from line {last_line}"
    return None

def test_chat_screen():
    path = 'lib/screens/messages/chat_screen.dart'
    assert os.path.exists(path), f"File {path} does not exist"
    
    err = check_brackets(path)
    assert err is None, f"Bracket error in {path}: {err}"
    
    content = open(path, 'r', encoding='utf-8').read()
    
    # Check imports
    assert "import 'package:record/record.dart';" in content, "record import missing"
    assert "import 'package:audioplayers/audioplayers.dart';" in content, "audioplayers import missing"
    assert "import 'package:file_picker/file_picker.dart';" in content, "file_picker import missing"
    assert "import 'package:image_picker/image_picker.dart';" in content, "image_picker import missing"
    assert "import 'package:url_launcher/url_launcher.dart';" in content, "url_launcher import missing"
    
    # Check AudioRecorder setup & config
    assert "AudioRecorder()" in content, "AudioRecorder instantiation missing"
    assert "AudioEncoder.aacLc" in content, "AAC LC encoder missing"
    assert "sampleRate: 44100" in content, "sampleRate missing"
    assert "bitRate: 128000" in content, "bitRate missing"
    assert ".m4a" in content, "m4a file extension missing"
    assert "_audioRecorder.start(" in content, "_audioRecorder.start call missing"
    assert "_audioRecorder.stop()" in content, "_audioRecorder.stop call missing"
    assert "_audioRecorder.hasPermission()" in content, "Permission check missing"
    
    # Check Voice Upload & Payload
    assert "StorageService.uploadVoiceNote(" in content, "uploadVoiceNote call missing"
    assert "type: 'voice'" in content, "Voice message type missing"
    assert "audioDurationSeconds:" in content, "audioDurationSeconds parameter missing"
    
    # Check AudioPlayer setup, listeners & disposal
    assert "AudioPlayer()" in content, "AudioPlayer instantiation missing"
    assert "_audioPlayer.onPlayerStateChanged.listen" in content, "onPlayerStateChanged listener missing"
    assert "_audioPlayer.onPositionChanged.listen" in content, "onPositionChanged listener missing"
    assert "_audioPlayer.onDurationChanged.listen" in content, "onDurationChanged listener missing"
    assert "_audioPlayer.onPlayerComplete.listen" in content, "onPlayerComplete listener missing"
    
    # Check player stream subscription cancellations
    assert "_playerStateSub?.cancel()" in content, "_playerStateSub cancel missing"
    assert "_playerPositionSub?.cancel()" in content, "_playerPositionSub cancel missing"
    assert "_playerDurationSub?.cancel()" in content, "_playerDurationSub cancel missing"
    assert "_playerCompleteSub?.cancel()" in content, "_playerCompleteSub cancel missing"
    assert "_recordingTimer?.cancel()" in content, "_recordingTimer cancel missing"
    assert "_audioPlayer.dispose()" in content, "_audioPlayer dispose missing"
    assert "_audioRecorder.dispose()" in content, "_audioRecorder dispose missing"
    
    # Check Audio streaming & Waveform
    assert "UrlSource(url)" in content, "UrlSource missing"
    assert "_playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds" in content, "Waveform ratio sync missing"
    assert "progressRatio >= barThreshold" in content, "Waveform bar threshold calculation missing"
    
    # Check NO Paste Dialogs or link popups
    assert "Paste Image URL" not in content, "'Paste Image URL' found in chat_screen.dart"
    assert "_showAddLinkDialog" not in content, "_showAddLinkDialog found in chat_screen.dart"
    
    # Check Document launcher
    assert "launchUrl(uri, mode: LaunchMode.externalApplication)" in content, "External application launchUrl missing"
    
    print("[PASS] ChatScreen empirical checks passed.")

def test_post_announcement_dialog():
    path = 'lib/screens/announcements/post_announcement_dialog.dart'
    assert os.path.exists(path), f"File {path} does not exist"
    
    err = check_brackets(path)
    assert err is None, f"Bracket error in {path}: {err}"
    
    content = open(path, 'r', encoding='utf-8').read()
    assert "Clipboard" not in content, "Clipboard found in post_announcement_dialog"
    assert "FilePicker.platform.pickFiles" in content, "FilePicker call missing"
    assert "StorageService.uploadAnnouncementAttachment" in content, "uploadAnnouncementAttachment call missing"
    assert "_isUploadingAttachment" in content, "Upload spinner state missing"
    assert "_removeAttachment" in content, "Attachment removal missing"
    
    print("[PASS] PostAnnouncementDialog empirical checks passed.")

def test_storage_service():
    path = 'lib/core/services/storage_service.dart'
    assert os.path.exists(path), f"File {path} does not exist"
    
    err = check_brackets(path)
    assert err is None, f"Bracket error in {path}: {err}"
    
    content = open(path, 'r', encoding='utf-8').read()
    assert "announcement_attachments" in content, "announcement_attachments bucket missing"
    assert "chat_attachments" in content, "chat_attachments bucket missing"
    assert "voice_messages" in content, "voice_messages bucket missing"
    assert "uploadFile" in content, "uploadFile missing"
    assert "getPublicUrl" in content, "getPublicUrl missing"
    assert "uploadVoiceNote" in content, "uploadVoiceNote missing"
    assert "uploadAnnouncementAttachment" in content, "uploadAnnouncementAttachment missing"
    assert "uploadChatAttachment" in content, "uploadChatAttachment missing"
    
    print("[PASS] StorageService empirical checks passed.")

def test_permissions():
    manifest = open('android/app/src/main/AndroidManifest.xml', encoding='utf-8').read()
    required = [
        'android.permission.RECORD_AUDIO',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.READ_MEDIA_VIDEO',
        'android.permission.READ_MEDIA_AUDIO',
        'android.permission.CAMERA'
    ]
    for p in required:
        assert p in manifest, f"Permission {p} missing in AndroidManifest.xml"
        
    plist = open('ios/Runner/Info.plist', encoding='utf-8').read()
    for key in ['NSMicrophoneUsageDescription', 'NSPhotoLibraryUsageDescription', 'NSCameraUsageDescription']:
        assert f'<key>{key}</key>' in plist, f"Apple privacy key {key} missing in Info.plist"
        
    print("[PASS] Native permissions and Apple privacy descriptions verified.")

if __name__ == '__main__':
    print("Running Challenger 2 Verification Harness...")
    test_chat_screen()
    test_post_announcement_dialog()
    test_storage_service()
    test_permissions()
    print("ALL EMPIRICAL TESTS PASSED SUCCESSFULLY!")
