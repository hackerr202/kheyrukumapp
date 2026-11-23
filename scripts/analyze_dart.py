#!/usr/bin/env python3
import os
import re

files_to_check = [
    "lib/core/localization/app_localizations.dart",
    "lib/core/localization/locale_notifier.dart",
    "lib/core/models/payment.dart",
    "lib/core/models/student.dart",
    "lib/core/services/auth_session_service.dart",
    "lib/core/services/payment_service.dart",
    "lib/core/services/push_notification_service.dart",
    "lib/core/services/storage_service.dart",
    "lib/core/services/student_service.dart",
    "lib/main.dart",
    "lib/screens/admin/user_management_screen.dart",
    "lib/screens/dashboard/dashboard_screen.dart",
    "lib/screens/dashboard/tabs/home_tab.dart",
    "lib/screens/dashboard/tabs/messages_tab.dart",
    "lib/screens/dashboard/tabs/more_tab.dart",
    "lib/screens/dashboard/tabs/settings_tab.dart",
    "lib/screens/payments/payments_screen.dart",
    "lib/widgets/add_student_dialog.dart",
]

for fpath in files_to_check:
    if not os.path.exists(fpath):
        print(f"MISSING: {fpath}")
        continue
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()
    print(f"Checking {fpath} ({len(content.splitlines())} lines)...")
