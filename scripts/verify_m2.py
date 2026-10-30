import os
import re
import sys
from check_syntax import check_brackets

def verify_messages_tab():
    path = 'lib/screens/dashboard/tabs/messages_tab.dart'
    if not os.path.exists(path):
        return False, f"File missing: {path}"
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. FAB clearance padding >= 90
    fab_match = re.search(r'floatingActionButton:\s*Padding\(\s*padding:\s*const\s*EdgeInsets\.only\([^)]*bottom:\s*(\d+)', content)
    if not fab_match:
        return False, "FAB is not wrapped in Padding with bottom clearance"
    bottom_pad = int(fab_match.group(1))
    if bottom_pad < 90:
        return False, f"FAB bottom clearance padding {bottom_pad} is < 90px"

    # 2. FAB label '+ New Chat'
    if "'+ New Chat'" not in content and '"+ New Chat"' not in content:
        return False, "FAB does not contain label '+ New Chat'"

    # 3. ListView bottom padding >= 125
    list_pad_match = re.search(r'EdgeInsets\.fromLTRB\(\s*\d+,\s*\d+,\s*\d+,\s*(\d+)\s*\)', content)
    if not list_pad_match:
        return False, "ListView padding EdgeInsets.fromLTRB not found"
    list_bottom_pad = int(list_pad_match.group(1))
    if list_bottom_pad < 125:
        return False, f"ListView bottom padding {list_bottom_pad} is < 125px"

    # 4. Empty state has 'Start Conversation' button
    if 'Start Conversation' not in content:
        return False, "Empty state does not contain 'Start Conversation' button"

    # 5. Role badges present
    if '_buildRoleBadge' not in content:
        return False, "Role badge builder _buildRoleBadge not found"

    return True, f"messages_tab.dart verified (FAB bottom: {bottom_pad}px, label: '+ New Chat', list bottom: {list_bottom_pad}px, empty state CTA & role badges present)"

def verify_home_tab():
    path = 'lib/screens/dashboard/tabs/home_tab.dart'
    if not os.path.exists(path):
        return False, f"File missing: {path}"
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Announcements carousel renders >= 3 items
    take_match = re.search(r'announcements\.take\((\d+)\)', content)
    if not take_match:
        return False, "announcements.take(...) not found in home_tab.dart"
    take_count = int(take_match.group(1))
    if take_count < 3:
        return False, f"Carousel takes {take_count} announcements, expected >= 3"

    # 2. Carousel / PageView exists
    if 'PageView' not in content or '_AnnouncementsCarousel' not in content:
        return False, "PageView or _AnnouncementsCarousel not found in home_tab.dart"

    # 3. _buildAdminCenterStatusCard re-integrated in build()
    # Check that it is invoked in build()
    build_method_match = re.search(r'Widget build\(BuildContext context\).*?(?=Widget _build)', content, re.DOTALL)
    if not build_method_match:
        return False, "Could not isolate build() method in home_tab.dart"
    build_body = build_method_match.group(0)
    if '_buildAdminCenterStatusCard' not in build_body:
        return False, "_buildAdminCenterStatusCard is not included in build() method"

    return True, f"home_tab.dart verified (carousel renders >= {take_count} items, _buildAdminCenterStatusCard included in build())"

def verify_app_theme():
    path = 'lib/core/theme/app_theme.dart'
    if not os.path.exists(path):
        return False, f"File missing: {path}"
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. darkTheme initializes GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)
    if 'GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)' not in content:
        return False, "GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme) not found in darkTheme"

    # 2. dialogTheme is defined
    if 'dialogTheme:' not in content or 'DialogTheme(' not in content:
        return False, "dialogTheme is not defined in ThemeData"

    # 3. inputDecorationTheme is defined
    if 'inputDecorationTheme:' not in content or 'InputDecorationTheme(' not in content:
        return False, "inputDecorationTheme is not defined in ThemeData"

    return True, "app_theme.dart verified (ThemeData.dark().textTheme used, dialogTheme & inputDecorationTheme defined)"

def verify_syntax():
    files = [
        'lib/screens/dashboard/tabs/messages_tab.dart',
        'lib/screens/dashboard/tabs/home_tab.dart',
        'lib/core/theme/app_theme.dart',
    ]
    for f in files:
        errs = check_brackets(f)
        if errs:
            return False, f"Syntax errors in {f}: {errs}"
    return True, "Syntax verification passed (0 errors across all M2 files)"

def main():
    print("=== Running M2 Verification Suite ===")
    checks = [
        ("messages_tab.dart", verify_messages_tab),
        ("home_tab.dart", verify_home_tab),
        ("app_theme.dart", verify_app_theme),
        ("Syntax Integrity", verify_syntax),
    ]

    all_passed = True
    for name, check_fn in checks:
        passed, msg = check_fn()
        status = "[PASS]" if passed else "[FAIL]"
        print(f"{status} {name}: {msg}")
        if not passed:
            all_passed = False

    if all_passed:
        print("\nALL M2 VERIFICATION CHECKS PASSED SUCCESSFULLY!")
        sys.exit(0)
    else:
        print("\nSOME M2 VERIFICATION CHECKS FAILED.")
        sys.exit(1)

if __name__ == '__main__':
    main()
