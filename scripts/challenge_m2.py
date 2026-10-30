import os
import re
import sys

def test_messages_tab():
    with open('lib/screens/dashboard/tabs/messages_tab.dart', 'r', encoding='utf-8') as f:
        src = f.read()

    # 1. FAB bottom clearance padding
    fab_match = re.search(r'floatingActionButton:\s*Padding\(\s*padding:\s*const\s*EdgeInsets\.only\([^)]*bottom:\s*(\d+)', src)
    assert fab_match, "FAB must be wrapped in bottom padding"
    pad = int(fab_match.group(1))
    assert pad >= 90, f"FAB bottom padding {pad} must be >= 90px to clear MeniscusNavBar (dock height 58 + bottom 22 = 80px)"

    # 2. FAB label
    assert "'+ New Chat'" in src or '"+ New Chat"' in src, "FAB label must be '+ New Chat'"

    # 3. List bottom padding
    list_match = re.search(r'ListView\(\s*padding:\s*const\s*EdgeInsets\.fromLTRB\(\s*\d+,\s*\d+,\s*\d+,\s*(\d+)\s*\)', src)
    assert list_match, "ListView must specify EdgeInsets.fromLTRB"
    list_pad = int(list_match.group(1))
    assert list_pad >= 125, f"ListView bottom padding {list_pad} must be >= 125px"

    # 4. Multi-role FAB & CTA handling
    # Check that onPressed has branching for isAdmin, isTeacher, and else (parent)
    fab_section = src[fab_match.start():fab_match.start()+700]
    assert 'isAdmin' in fab_section, "FAB onPressed must branch on isAdmin"
    assert 'isTeacher' in fab_section, "FAB onPressed must branch on isTeacher"
    assert '_showAdminActionSheet' in fab_section, "Admin action must invoke _showAdminActionSheet"
    assert '_showTeacherMessageParentSheet' in fab_section, "Teacher action must invoke _showTeacherMessageParentSheet"
    assert '_startParentDirectChat' in fab_section, "Parent action must invoke _startParentDirectChat"

    # 5. Empty State Action Button
    assert 'Start Conversation' in src, "Empty state must include actionable 'Start Conversation' button"
    empty_btn_idx = src.find('Start Conversation')
    btn_start = src.rfind('ElevatedButton.icon', 0, empty_btn_idx)
    surrounding = src[btn_start:empty_btn_idx+100]
    assert 'isAdmin' in surrounding and 'isTeacher' in surrounding and '_startParentDirectChat' in surrounding, \
        "Empty state button must dispatch role-specific chat actions"

    # 6. Role badges
    for role in ['Admin', 'Ustaz', 'Circle', 'Parent']:
        assert f"'{role}'" in src, f"Role badge for {role} must be defined in messages_tab.dart"

    print("[PASS] messages_tab.dart adversarial checks passed")

def test_home_tab():
    with open('lib/screens/dashboard/tabs/home_tab.dart', 'r', encoding='utf-8') as f:
        src = f.read()

    # 1. Carousel takes >= 3 announcements
    take_match = re.search(r'announcements\.take\((\d+)\)', src)
    assert take_match, "announcements.take(...) not found"
    count = int(take_match.group(1))
    assert count >= 3, f"Carousel takes {count} items, expected >= 3"

    # 2. PageView used
    assert 'PageView.builder' in src, "PageView.builder must be used for announcements carousel"

    # 3. List bottom padding >= 100
    list_match = re.search(r'ListView\(\s*padding:\s*const\s*EdgeInsets\.fromLTRB\(\s*\d+,\s*\d+,\s*\d+,\s*(\d+)\s*\)', src)
    assert list_match, "ListView EdgeInsets.fromLTRB not found in home_tab.dart"
    bottom_pad = int(list_match.group(1))
    assert bottom_pad >= 100, f"ListView bottom padding {bottom_pad} must be >= 100px"

    # 4. _buildAdminCenterStatusCard included in build()
    build_match = re.search(r'Widget build\(BuildContext context\).*?(?=Widget _build)', src, re.DOTALL)
    assert build_match, "build method not matched"
    build_code = build_match.group(0)
    assert '_buildAdminCenterStatusCard' in build_code, "_buildAdminCenterStatusCard must be called in build()"

    # 5. Admin Center Status Card handles both onboarding checklist and live stats
    assert 'Students' in src and 'Halaqahs' in src and 'Teachers' in src, "Stats items must be present"
    assert 'Center setup' in src, "Onboarding setup card must be present"

    print("[PASS] home_tab.dart adversarial checks passed")

def test_app_theme():
    with open('lib/core/theme/app_theme.dart', 'r', encoding='utf-8') as f:
        src = f.read()

    # 1. darkTheme bases text on ThemeData.dark().textTheme
    assert 'GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)' in src, \
        "darkTheme must seed poppinsTextTheme with ThemeData.dark().textTheme"

    # 2. dialogTheme
    assert 'dialogTheme:' in src, "dialogTheme must be defined in darkTheme"
    assert 'DialogTheme(' in src
    assert 'AppColors.textPrimary' in src
    assert 'AppColors.surfaceCard' in src

    # 3. inputDecorationTheme
    assert 'inputDecorationTheme:' in src, "inputDecorationTheme must be defined in darkTheme"
    assert 'InputDecorationTheme(' in src
    assert 'fillColor: const Color(0xFF0F172A)' in src

    print("[PASS] app_theme.dart adversarial checks passed")

if __name__ == '__main__':
    print("=== Running Adversarial Stress-Test Suite for M2 ===")
    test_messages_tab()
    test_home_tab()
    test_app_theme()
    print("ALL ADVERSARIAL CHECKS PASSED!")
