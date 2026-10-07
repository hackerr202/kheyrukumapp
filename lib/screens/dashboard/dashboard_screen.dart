import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/announcement.dart';
import '../../core/models/app_notification.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/notification_center_service.dart';
import '../../core/services/prayer_reminder_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/announcement_banner.dart';
import '../../widgets/meniscus_nav_bar.dart';
import '../announcements/announcements_sheet.dart';
import '../announcements/post_announcement_dialog.dart';
import '../settings/settings_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/homework_tab.dart';
import 'tabs/messages_tab.dart';
import 'tabs/more_tab.dart';
import 'tabs/students_tab.dart';

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
  int _unreadNotificationsCount = NotificationCenterService.instance.unreadCount;
  Announcement? _activeAlertAnnouncement;
  Timer? _alertDismissTimer;
  StreamSubscription<Announcement>? _alertSub;
  StreamSubscription<List<Announcement>>? _announcementsSub;
  StreamSubscription<List<AppNotification>>? _notifsSub;
  StreamSubscription<Map<String, String>>? _prayerSub;

  int get _totalUnreadCount => _unreadAnnouncementsCount + _unreadNotificationsCount;

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

    // 3. Stream unread system notifications (attendance, weekly reports, tuition, payments)
    _notifsSub = NotificationCenterService.instance.stream.listen((list) {
      if (!mounted) return;
      setState(() => _unreadNotificationsCount = NotificationCenterService.instance.unreadCount);
    });

    // 4. Start 10-minute prayer reminder schedule for all users and admin
    PrayerReminderService.instance.start();
    _prayerSub = PrayerReminderService.instance.onPrayerAlert.listen((alert) {
      if (!mounted) return;
      _triggerAlertToast(Announcement(
        id: 'prayer-${DateTime.now().millisecondsSinceEpoch}',
        title: alert['title'] ?? 'Prayer & Dhikr Reminder 🕌',
        content: alert['body'] ?? 'Turn your heart towards Allah in prayer and remembrance.',
        category: 'urgent',
        targetAudience: 'all',
        authorName: 'Adhan & Prayer Reminder',
        isPinned: true,
        createdAt: DateTime.now(),
      ));
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
    _notifsSub?.cancel();
    _prayerSub?.cancel();
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
      icon: Icons.grid_view_rounded,
      label: 'More',
      accentColor: Color(0xFFFF4B72), // Neon Rose
    ),
  ];

  final List<Widget> _pages = const [
    HomeTab(),
    StudentsTab(), // Multi-child parent view & Admin student roster
    MessagesTab(),
    HomeworkTab(),
    MoreTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        final activeItem = _navItems[_currentTabIndex];
        final isDark = themeMode == ThemeMode.dark;
        final headerBtnBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final headerBorderColor = isDark ? const Color(0xFF334155) : AppColors.borderSubtleLight;

        return Scaffold(
          backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
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
                ValueListenableBuilder<String>(
                  valueListenable: AuthSessionService.instance.roleNotifier,
                  builder: (context, currentRole, _) {
                    final isAdmin = currentRole == 'admin';
                    final isTeacher = currentRole == 'teacher';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Admin Broadcast Button ONLY for Admin
                          if (isAdmin)
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
                            )
                          else
                            // Teacher & Parent header badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: headerBtnBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (isTeacher ? AppColors.accentTeal : AppColors.accentAmber).withOpacity(0.4),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isTeacher ? Icons.school_rounded : Icons.family_restroom_rounded,
                                    size: 14,
                                    color: isTeacher ? AppColors.accentTeal : AppColors.accentAmber,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isTeacher ? 'Teacher' : 'Parent',
                                    style: TextStyle(
                                      color: isTeacher ? AppColors.accentTeal : AppColors.accentAmber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
                                isTeacher
                                    ? 'TEACHER PORTAL'
                                    : (isAdmin ? 'ADMIN PORTAL' : 'PARENT PORTAL'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: isDark ? Colors.white.withOpacity(0.7) : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),

                          // Actions: Notification Bell + Settings
                          Row(
                        children: [
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
                              if (_totalUnreadCount > 0)
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
                                        '$_totalUnreadCount',
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

                          const SizedBox(width: 8),

                          // Settings Button (beside notification bell)
                          InkWell(
                            onTap: () => SettingsSheet.show(context),
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
                                Icons.settings_outlined,
                                size: 18,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

                const SizedBox(height: 12),

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
  },
);
}
}
