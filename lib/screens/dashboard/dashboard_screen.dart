import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/announcement.dart';
import '../../core/services/announcement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/announcement_banner.dart';
import '../../widgets/meniscus_nav_bar.dart';
import '../announcements/announcements_sheet.dart';
import '../announcements/post_announcement_dialog.dart';
import 'tabs/home_tab.dart';
import 'tabs/homework_tab.dart';
import 'tabs/messages_tab.dart';
import 'tabs/settings_tab.dart';

/// Main Dashboard Screen styled precisely after the reference Meniscus demonstration,
/// integrated with Supabase Realtime announcement broadcasts and immediate notifications.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTabIndex = 0;
  int _unreadAnnouncementsCount = 0;
  Announcement? _activeAlertAnnouncement;
  Timer? _alertDismissTimer;
  StreamSubscription<Announcement>? _alertSub;
  StreamSubscription<List<Announcement>>? _announcementsSub;

  @override
  void initState() {
    super.initState();

    // 1. Listen for immediate popup alerts when a new announcement arrives
    _alertSub = AnnouncementService.instance.onNewAnnouncementAlert.listen((announcement) {
      if (!mounted) return;
      _triggerAlertToast(announcement);
    });

    // 2. Stream unread announcements count from Supabase Realtime
    _announcementsSub = AnnouncementService.instance.streamAnnouncements().listen((list) {
      if (!mounted) return;
      final unread = list.where((a) => !AnnouncementService.instance.isRead(a.id)).length;
      setState(() => _unreadAnnouncementsCount = unread);
    });
  }

  void _triggerAlertToast(Announcement announcement) {
    _alertDismissTimer?.cancel();
    setState(() => _activeAlertAnnouncement = announcement);

    // Auto-dismiss notification toast after 6 seconds
    _alertDismissTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _activeAlertAnnouncement = null);
    });
  }

  @override
  void dispose() {
    _alertDismissTimer?.cancel();
    _alertSub?.cancel();
    _announcementsSub?.cancel();
    super.dispose();
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? Colors.white.withOpacity(0.55) : AppColors.textSecondaryLight;
    final headerBtnBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final headerBorderColor = isDark ? const Color(0xFF334155) : AppColors.borderSubtleLight;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      activeItem.accentColor.withOpacity(isDark ? 0.12 : 0.08),
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
                const SizedBox(height: 8),

                // Top Header Bar: Admin Broadcast + Title + Notification Bell
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Admin Broadcast Button
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const PostAnnouncementDialog(),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: headerBtnBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFA000).withOpacity(0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.campaign_rounded, size: 14, color: Color(0xFFFFA000)),
                              SizedBox(width: 4),
                              Text(
                                'Post Notice',
                                style: TextStyle(
                                  color: Color(0xFFFFA000),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Center Pill
                      Row(
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
                          const SizedBox(width: 6),
                          Text(
                            'KHEYRUKUM PORTAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: isDark ? Colors.white.withOpacity(0.7) : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),

                      // Notification Bell with Unread Count Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() => _unreadAnnouncementsCount = 0);
                              AnnouncementsSheet.show(context);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: headerBtnBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: headerBorderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                size: 18,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                          if (_unreadAnnouncementsCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF4B72),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_unreadAnnouncementsCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),


                const SizedBox(height: 10),

                // Hero Title (Huge bold typography like the video)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    headerInfo['title']!,
                    key: ValueKey<String>(headerInfo['title']!),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
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
                      color: subtitleColor,
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
          // Real-time Incoming Announcement Notification Banner (drops down from top)
          if (_activeAlertAnnouncement != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnnouncementBanner(
                announcement: _activeAlertAnnouncement!,
                onTap: () {
                  setState(() => _activeAlertAnnouncement = null);
                  AnnouncementsSheet.show(context);
                },
                onDismiss: () {
                  setState(() => _activeAlertAnnouncement = null);
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
