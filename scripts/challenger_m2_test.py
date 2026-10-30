import re
import sys
import os

def test_geometry_and_clearance():
    print("--- 1. Geometry & Dock Clearance Verification ---")
    
    # 1. Inspect dashboard_screen.dart for MeniscusNavBar positioning
    dash_path = 'lib/screens/dashboard/dashboard_screen.dart'
    with open(dash_path, 'r', encoding='utf-8') as f:
        dash_content = f.read()
    
    nav_pos_match = re.search(r'Positioned\([^)]*bottom:\s*(\d+)[^)]*child:\s*MeniscusNavBar', dash_content, re.DOTALL)
    if not nav_pos_match:
        # try searching with whitespace variation
        nav_pos_match = re.search(r'bottom:\s*(\d+),\s*child:\s*MeniscusNavBar', dash_content)
    assert nav_pos_match is not None, "Failed to find MeniscusNavBar Positioned bottom in dashboard_screen.dart"
    dock_bottom = float(nav_pos_match.group(1))
    print(f"[FOUND] MeniscusNavBar positioned at bottom: {dock_bottom}px")

    # 2. Inspect meniscus_nav_bar.dart for dock height and top overflow
    nav_path = 'lib/widgets/meniscus_nav_bar.dart'
    with open(nav_path, 'r', encoding='utf-8') as f:
        nav_content = f.read()
    
    dock_height_match = re.search(r'const\s+double\s+dockHeight\s*=\s*([\d\.]+);', nav_content)
    top_overflow_match = re.search(r'const\s+double\s+topOverflow\s*=\s*([\d\.]+);', nav_content)
    assert dock_height_match is not None, "dockHeight not found in meniscus_nav_bar.dart"
    assert top_overflow_match is not None, "topOverflow not found in meniscus_nav_bar.dart"
    
    dock_height = float(dock_height_match.group(1))
    top_overflow = float(top_overflow_match.group(1))
    total_nav_height = dock_height + top_overflow
    dock_top = dock_bottom + total_nav_height
    print(f"[FOUND] dockHeight: {dock_height}px, topOverflow: {top_overflow}px -> totalHeight: {total_nav_height}px")
    print(f"[COMPUTED] Meniscus dock top boundary: {dock_top}px from screen bottom")

    # 3. Inspect messages_tab.dart for FAB elevation and ListView padding
    msg_path = 'lib/screens/dashboard/tabs/messages_tab.dart'
    with open(msg_path, 'r', encoding='utf-8') as f:
        msg_content = f.read()

    fab_pad_match = re.search(r'floatingActionButton:\s*Padding\(\s*padding:\s*const\s*EdgeInsets\.only\([^)]*bottom:\s*(\d+)', msg_content)
    assert fab_pad_match is not None, "FAB Padding bottom not found in messages_tab.dart"
    fab_bottom_pad = float(fab_pad_match.group(1))
    print(f"[FOUND] FAB bottom padding: {fab_bottom_pad}px")

    # Flutter standard kFloatingActionButtonMargin
    kFloatingActionButtonMargin = 16.0
    total_fab_elevation = kFloatingActionButtonMargin + fab_bottom_pad
    print(f"[COMPUTED] Total FAB elevation (margin 16px + padding {fab_bottom_pad}px): {total_fab_elevation}px")

    assert total_fab_elevation >= 114.0, f"Total FAB elevation {total_fab_elevation}px is < 114px"
    assert total_fab_elevation > dock_top, f"FAB elevation {total_fab_elevation}px does not clear dock top {dock_top}px"
    clearance = total_fab_elevation - dock_top
    print(f"[RESULT] FAB completely clears the dock with {clearance}px clearance gap!")

    # 4. Check label
    assert "'+ New Chat'" in msg_content or '"+ New Chat"' in msg_content, "Label '+ New Chat' not found in messages_tab.dart"
    print("[PASSED] FAB label is verified as '+ New Chat'")

    # 5. Check ListView bottom padding
    list_pad_match = re.search(r'EdgeInsets\.fromLTRB\(\s*[\d\.]+,\s*[\d\.]+,\s*[\d\.]+,\s*([\d\.]+)\s*\)', msg_content)
    assert list_pad_match is not None, "ListView padding EdgeInsets.fromLTRB not found in messages_tab.dart"
    list_bottom_pad = float(list_pad_match.group(1))
    print(f"[FOUND] ListView bottom padding: {list_bottom_pad}px")
    assert list_bottom_pad >= 125.0, f"ListView bottom padding {list_bottom_pad}px is < 125px"
    print(f"[PASSED] ListView bottom padding is {list_bottom_pad}px (>= 125px requirement met)")

def test_role_dispatch_logic():
    print("\n--- 2. FAB Role Dispatch & Accessibility Verification ---")
    msg_path = 'lib/screens/dashboard/tabs/messages_tab.dart'
    with open(msg_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Verify that FAB onPressed handles admin, teacher, and parent roles:
    fab_slice = content[content.find('floatingActionButton:'):content.find('Widget _buildQuickActionButton')]
    assert 'isAdmin' in fab_slice, "Admin check missing in FAB onPressed"
    assert '_showAdminActionSheet' in fab_slice, "Admin handler missing in FAB onPressed"
    assert 'isTeacher' in fab_slice, "Teacher check missing in FAB onPressed"
    assert '_showTeacherMessageParentSheet' in fab_slice, "Teacher handler missing in FAB onPressed"
    assert '_startParentDirectChat' in fab_slice, "Parent handler missing in FAB onPressed"
    print("[PASSED] All 3 roles (Admin, Teacher, Parent) have active FAB handlers")

def test_empty_state_and_list_decorations():
    print("\n--- 3. Empty State & List Decorations Verification ---")
    msg_path = 'lib/screens/dashboard/tabs/messages_tab.dart'
    with open(msg_path, 'r', encoding='utf-8') as f:
        content = f.read()

    assert 'Start Conversation' in content, "Start Conversation button missing in empty state"
    assert '_buildRoleBadge' in content, "_buildRoleBadge missing in messages_tab.dart"
    assert 'Admin' in content and 'Ustaz' in content and 'Circle' in content and 'Parent' in content, "Role badge labels missing"
    print("[PASSED] Empty state CTA and role badges verified")

def main():
    try:
        test_geometry_and_clearance()
        test_role_dispatch_logic()
        test_empty_state_and_list_decorations()
        print("\nALL EMPIRICAL CHALLENGER VERIFICATIONS PASSED!")
    except AssertionError as e:
        print(f"\n[FAIL] Assertion failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
