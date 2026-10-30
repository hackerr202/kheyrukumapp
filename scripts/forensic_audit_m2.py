import os
import re
import sys

def audit_messages_tab():
    path = 'lib/screens/dashboard/tabs/messages_tab.dart'
    if not os.path.exists(path):
        return False, f"File not found: {path}"
    with open(path, 'r', encoding='utf-8') as f:
        src = f.read()

    # 1. FAB bottom clearance
    fab_match = re.search(r'floatingActionButton:\s*Padding\(\s*padding:\s*const\s*EdgeInsets\.only\([^)]*bottom:\s*(\d+)', src)
    if not fab_match:
        return False, "FAB not wrapped in Padding with bottom clearance"
    bottom_pad = int(fab_match.group(1))
    if bottom_pad < 90:
        return False, f"FAB bottom padding {bottom_pad}px is less than required 90px"

    # 2. FAB label & icon
    if "'+ New Chat'" not in src and '"+ New Chat"' not in src:
        return False, "FAB label '+ New Chat' missing"
    if 'Icons.add_comment_rounded' not in src:
        return False, "FAB icon Icons.add_comment_rounded missing"

    # 3. FAB available to all roles
    if 'if (isAdmin)' not in src or 'else if (isTeacher)' not in src or 'else {' not in src:
        return False, "FAB role branching (admin, teacher, parent) missing"

    # 4. ListView bottom clearance
    list_match = re.search(r'EdgeInsets\.fromLTRB\(\s*\d+,\s*\d+,\s*\d+,\s*(\d+)\s*\)', src)
    if not list_match:
        return False, "ListView padding not found"
    list_bottom = int(list_match.group(1))
    if list_bottom < 125:
        return False, f"ListView bottom padding {list_bottom}px is less than 125px"

    # 5. Empty state CTA
    if 'Start Conversation' not in src:
        return False, "Empty state missing 'Start Conversation' CTA button"
    if 'Clear Search' not in src:
        return False, "Empty state missing 'Clear Search' button"

    # 6. Role badge builder
    if '_buildRoleBadge' not in src:
        return False, "_buildRoleBadge not implemented"
    for role in ['Admin', 'Ustaz', 'Circle', 'Parent']:
        if f"badgeText = '{role}'" not in src and f'badgeText = "{role}"' not in src:
            return False, f"Role badge for '{role}' not implemented"

    # 7. Time formatting
    if 'Just now' not in src or 'AM' not in src or 'PM' not in src:
        return False, "_formatTime missing relative or 12-hour AM/PM formatting"

    # 8. Unread badge formatting
    if "'99+'" not in src and '"99+"' not in src:
        return False, "Unread badge missing '99+' overflow truncation"

    return True, f"messages_tab.dart PASS (FAB clearance: {bottom_pad}px, list padding: {list_bottom}px, all roles supported, empty CTA, role badges verified)"

def audit_home_tab():
    path = 'lib/screens/dashboard/tabs/home_tab.dart'
    if not os.path.exists(path):
        return False, f"File not found: {path}"
    with open(path, 'r', encoding='utf-8') as f:
        src = f.read()

    # 1. Carousel widget existence
    if '_AnnouncementsCarousel' not in src:
        return False, "_AnnouncementsCarousel class missing"

    # 2. Carousel item count >= 3
    take_match = re.search(r'widget\.announcements\.take\((\d+)\)', src) or re.search(r'announcements\.take\((\d+)\)', src)
    if not take_match:
        return False, "announcements.take(...) not found"
    count = int(take_match.group(1))
    if count < 3:
        return False, f"Carousel takes {count} announcements, expected >= 3"

    # 3. PageController disposal
    if '_pageController.dispose()' not in src:
        return False, "_pageController not disposed in _AnnouncementsCarouselState"

    # 4. Admin center status card integrated
    build_method = re.search(r'Widget build\(BuildContext context\)\s*\{.*?(?=Widget _buildAdminCenterStatusCard)', src, re.DOTALL)
    if not build_method or '_buildAdminCenterStatusCard' not in build_method.group(0):
        return False, "_buildAdminCenterStatusCard not found in build() method body"

    # 5. Empty state for announcements
    if 'No announcements posted yet' not in src:
        return False, "Empty state for announcements missing"

    return True, f"home_tab.dart PASS (Carousel takes {count} items, PageView disposed, admin status card integrated in build, empty state handled)"

def audit_app_theme():
    path = 'lib/core/theme/app_theme.dart'
    if not os.path.exists(path):
        return False, f"File not found: {path}"
    with open(path, 'r', encoding='utf-8') as f:
        src = f.read()

    # 1. Dark theme typography
    if 'GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)' not in src:
        return False, "darkTheme does not pass ThemeData.dark().textTheme to GoogleFonts.poppinsTextTheme"

    # 2. dialogTheme
    if 'dialogTheme: DialogTheme(' not in src:
        return False, "dialogTheme: DialogTheme(...) not declared"

    # 3. inputDecorationTheme
    if 'inputDecorationTheme: InputDecorationTheme(' not in src:
        return False, "inputDecorationTheme: InputDecorationTheme(...) not declared"

    # 4. Text styles in dark theme
    for style in ['titleMedium', 'titleSmall', 'bodySmall', 'labelMedium', 'labelSmall']:
        if f'{style}: GoogleFonts.poppins(' not in src:
            return False, f"textTheme in darkTheme missing explicit {style}"

    return True, "app_theme.dart PASS (dark textTheme seeded with ThemeData.dark(), dialogTheme & inputDecorationTheme defined, full text typography specified)"

def main():
    print("=== FORENSIC DEEP AUDIT: MILESTONE M2 ===")
    audits = [
        ("Messages Tab Audit", audit_messages_tab),
        ("Home Tab Audit", audit_home_tab),
        ("App Theme Audit", audit_app_theme),
    ]

    all_pass = True
    for name, audit_fn in audits:
        ok, msg = audit_fn()
        status = "[PASS]" if ok else "[FAIL]"
        print(f"{status} {name}: {msg}")
        if not ok:
            all_pass = False

    if all_pass:
        print("\nALL FORENSIC AUDIT CHECKS PASSED: VERDICT CLEAN")
        sys.exit(0)
    else:
        print("\nFORENSIC AUDIT FOUND FAILURES: VERDICT INTEGRITY VIOLATION")
        sys.exit(1)

if __name__ == '__main__':
    main()
