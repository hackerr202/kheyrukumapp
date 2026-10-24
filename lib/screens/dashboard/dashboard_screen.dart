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
import '../settings/settings_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/homework_tab.dart';
import 'tabs/messages_tab.dart';
import 'tabs/more_tab.dart';
import 'tabs/students_tab.dart';

/// Main Dashboard Screen with a calm, spacious layout,
/// unified electric lime accent color, clean header, and floating Meniscus navigation.
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

    // 4. Start daily prayer reminder
    PrayerReminderService.instance.start();
    _prayerSub = PrayerReminderService.instance.onPrayerAlert.listen((alert) {
      if (!mounted) return;
      _triggerAlertToast(Announcement(
        id: 'prayer-${DateTime.now().millisecondsSinceEpoch}',
        title: alert['title'] ?? 'Don\'t forget to pray 🕌',
        content: alert['body'] ?? 'Take a peaceful moment to remember Allah.',
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

  // Consistent lime green as the single accent color across the app
  static const Color _limeAccent = Color(0xFFC9F24A);

  final List<MeniscusNavItem> _navItems = const [
    MeniscusNavItem(
      icon: Icons.home_rounded,
      label: 'Home',
      accentColor: _limeAccent,
    ),
    MeniscusNavItem(
      icon: Icons.person_rounded,
      label: 'Students',
      accentColor: _limeAccent,
    ),
    MeniscusNavItem(
      icon: Icons.chat_bubble_rounded,
      label: 'Messages',
      accentColor: _limeAccent,
    ),
    MeniscusNavItem(
      icon: Icons.menu_book_rounded,
      label: 'Homework',
      accentColor: _limeAccent,
    ),
    MeniscusNavItem(
      icon: Icons.grid_view_rounded,
      label: 'More',
      accentColor: _limeAccent,
    ),
  ];

  late final List<Widget> _pages = [
    HomeTab(
      onNavigateToTab: (index) {
        setState(() {
          _currentTabIndex = index;
        });
      },
    ),
    const StudentsTab(),
    const MessagesTab(),
    const HomeworkTab(),
    const MoreTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        final headerBtnBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final headerBorderColor = isDark ? const Color(0xFF334155).withOpacity(0.6) : AppColors.borderSubtleLight;

        return Scaffold(
          backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),

                    // Clean Header: Greeting + Avatar + Notification Bell + Settings Icon
                    ValueListenableBuilder<String>(
                      valueListenable: AuthSessionService.instance.roleNotifier,
                      builder: (context, currentRole, _) {
                        final userName = AuthSessionService.instance.userName;
                        final displayName = userName.isNotEmpty ? userName : 'Administrator';
                        final avatarInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  border: Border.all(
                                    color: _limeAccent.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    avatarInitial,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Greeting & User Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Assalamu Alaikum,',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Actions: Notification Bell + Settings
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Notification Bell with Badge
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() => _unreadAnnouncementsCount = 0);
                                          AnnouncementsSheet.show(context);
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: headerBtnBg,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: headerBorderColor),
                                          ),
                                          child: Icon(
                                            Icons.notifications_none_rounded,
                                            size: 20,
                                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ),
                                      if (_totalUnreadCount > 0)
                                        Positioned(
                                          top: -3,
                                          right: -3,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEF4444),
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

                                  // Settings Button
                                  InkWell(
                                    onTap: () => SettingsSheet.show(context),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: headerBtnBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: headerBorderColor),
                                      ),
                                      child: Icon(
                                        Icons.settings_outlined,
                                        size: 20,
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

                    // Dynamic Page Body driven by tab index
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.02),
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

              // Real-time Incoming Announcement Notification Banner
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
