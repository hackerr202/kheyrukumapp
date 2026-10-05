import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/meniscus_nav_bar.dart';
import 'tabs/home_tab.dart';
import 'tabs/homework_tab.dart';
import 'tabs/messages_tab.dart';
import 'tabs/settings_tab.dart';

/// Main Dashboard Screen styled precisely after the reference Meniscus demonstration.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTabIndex = 0;

  // 5 Tabs with distinct accent colors matching the video aesthetic
  final List<MeniscusNavItem> _navItems = const [
    MeniscusNavItem(
      icon: Icons.home_rounded,
      label: 'Home',
      accentColor: Color(0xFFC9F24A), // Electric Lime
    ),
    MeniscusNavItem(
      icon: Icons.person_rounded,
      label: 'Students',
      accentColor: Color(0xFF00BCD4), // Soft Cyan/Teal
    ),
    MeniscusNavItem(
      icon: Icons.chat_bubble_rounded,
      label: 'Messages',
      accentColor: Color(0xFFFFA000), // Warm Amber
    ),
    MeniscusNavItem(
      icon: Icons.menu_book_rounded,
      label: 'Homework',
      accentColor: Color(0xFF10B981), // Emerald
    ),
    MeniscusNavItem(
      icon: Icons.tune_rounded,
      label: 'Settings',
      accentColor: Color(0xFFFF4B72), // Neon Rose
    ),
  ];

  final List<Widget> _pages = const [
    HomeTab(),
    SettingsTab(), // Student Profiles & Halqah Level
    MessagesTab(),
    HomeworkTab(),
    SettingsTab(),
  ];

  final List<Map<String, String>> _tabHeaders = const [
    {'title': 'Home', 'subtitle': 'Everything, on one surface.'},
    {'title': 'Students', 'subtitle': 'Tracking Quranic progress & halaqah milestones.'},
    {'title': 'Messages', 'subtitle': 'Three unread. All of them kind.'},
    {'title': 'Homework', 'subtitle': 'Daily recitation & Tajweed assignments.'},
    {'title': 'Settings', 'subtitle': 'Fewer switches. Better defaults.'},
  ];

  @override
  Widget build(BuildContext context) {
    final activeItem = _navItems[_currentTabIndex];
    final headerInfo = _tabHeaders[_currentTabIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Ambient Radial Glow responding to active tab color
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            top: 40,
            left: 0,
            right: 0,
            height: 300,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 0.8,
                    colors: [
                      activeItem.accentColor.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // Top Header Pill: "● MENISCUS / KHEYRUKUM"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: activeItem.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeItem.accentColor.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'KHEYRUKUM PORTAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Hero Title (Huge bold white typography like the video)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    headerInfo['title']!,
                    key: ValueKey<String>(headerInfo['title']!),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Subtitle
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    headerInfo['subtitle']!,
                    key: ValueKey<String>(headerInfo['subtitle']!),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Dynamic Page Body driven by tab index
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.03),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuad)),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentTabIndex),
                      child: _pages[_currentTabIndex],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top Right Replay Splash Button
          Positioned(
            top: 48,
            right: 18,
            child: IconButton(
              icon: Icon(Icons.replay_rounded, color: activeItem.accentColor.withOpacity(0.8), size: 20),
              tooltip: 'Replay Splash Intro',
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/splash');
              },
            ),
          ),

          // Floating Meniscus Bottom Navigation Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: MeniscusNavBar(
              selectedIndex: _currentTabIndex,
              items: _navItems,
              onTabChanged: (index) {
                setState(() {
                  _currentTabIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
