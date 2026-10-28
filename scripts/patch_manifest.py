import re
import sys

manifest_path = sys.argv[1] if len(sys.argv) > 1 else 'android/app/src/main/AndroidManifest.xml'

with open(manifest_path, 'r', encoding='utf-8') as f:
    content = f.read()

permissions = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
"""

queries = """
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="tel" />
        </intent>
        <package android:name="org.telegram.messenger" />
        <package android:name="com.whatsapp" />
    </queries>
"""

receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            </intent-filter>
        </receiver>
"""

# Insert permissions right after <manifest ...>
if '<uses-permission' not in content:
    content = re.sub(r'(<manifest\b[^>]*>)', r'\1' + permissions, content, count=1)

# Insert queries right after permissions or after <manifest ...>
if '<queries>' not in content:
    content = re.sub(r'(<manifest\b[^>]*>)', r'\1' + queries, content, count=1)

# Insert receivers right after <application ...>
if 'ScheduledNotificationReceiver' not in content:
    content = re.sub(r'(<application\b[^>]*>)', r'\1' + receivers, content, count=1)

with open(manifest_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"Successfully patched {manifest_path}")
