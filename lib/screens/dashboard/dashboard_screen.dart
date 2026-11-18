import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/announcement.dart';
import '../../core/models/app_notification.dart';
import '../../core/services/absence_service.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/halaqah_service.dart';
import '../../core/services/homework_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/notification_center_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/prayer_reminder_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/student_service.dart';
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

    // Bootstrap authenticated session & all live cloud streams
    _bootstrapCloudServices();

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
        targetAudience: 'all',
        authorName: 'Adhan & Prayer Reminder',
        isPinned: true,
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<void> _bootstrapCloudServices() async {
    await AuthSessionService.instance.syncFromSupabaseProfile();
    await Future.wait([
      HalaqahService.instance.fetchHalaqahs(),
      StudentService.instance.refreshAll(),
      HomeworkService.instance.refreshAll(),
      AbsenceService.instance.refreshAll(),
      MessagingService.instance.refreshAndSubscribe(),
      PaymentService.instance.refreshAndSubscribe(),
      PushNotificationService.instance.registerDeviceToken(),
    ]);
    AnnouncementService.instance.refreshAndSubscribe();
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

  // Cohesive Kheyrukum Emerald accent across the app
  static const Color _limeAccent = AppColors.accentEmerald;

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
        final headerBtnBg = isDark ? AppColors.surfaceCard : Colors.white;
        final headerBorderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

        return Scaffold(
          backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),

                    // Refined App Header: Monogram Avatar + Greeting & Role Pill + Notifications + Settings
                    ValueListenableBuilder<String>(
                      valueListenable: AuthSessionService.instance.roleNotifier,
                      builder: (context, currentRole, _) {
                        final userName = AuthSessionService.instance.userName;
                        final displayName = userName.isNotEmpty ? userName : 'Administrator';
                        final avatarInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';
                        final roleLabel = currentRole == 'admin'
                            ? 'Director'
                            : (currentRole == 'teacher' ? 'Ustaz' : 'Parent');
                        final roleColor = currentRole == 'admin'
                            ? AppColors.accentAmber
                            : (currentRole == 'teacher' ? AppColors.accentTealLight : AppColors.accentEmerald);

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                          child: Row(
                            children: [
                              // Monogram Avatar with gradient ring
                              Container(
                                width: 44,
                                height: 44,
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.journeyGradient,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? AppColors.surfaceCard : Colors.white,
                                  ),
                                  child: Center(
                                    child: Text(
                                      avatarInitial,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Greeting + User Name + Role Pill
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Assalamu Alaikum',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: roleColor.withOpacity(0.14),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: roleColor.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            roleLabel.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: roleColor,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
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
                                        onTap: () => _showUnifiedNotificationsSheet(context),
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: headerBtnBg,
                                            borderRadius: BorderRadius.circular(14),
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
                                              color: AppColors.accentCoral,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            child: Center(
                                              child: Text(
                                                _totalUnreadCount > 9 ? '9+' : '$_totalUnreadCount',
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

                                  const SizedBox(width: 10),

                                  // Settings Button
                                  InkWell(
                                    onTap: () => SettingsSheet.show(context),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: headerBtnBg,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: headerBorderColor),
                                      ),
                                      child: Icon(
                                        Icons.tune_rounded,
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

  void _showUnifiedNotificationsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.surfaceCard : Colors.white;
    final cardBg = isDark ? AppColors.background : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    setState(() => _unreadAnnouncementsCount = 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          height: MediaQuery.of(sheetCtx).size.height * 0.78,
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity & Alerts',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                        ),
                        Text(
                          'Realtime updates across your account',
                          style: TextStyle(fontSize: 11.5, color: subtextColor),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            NotificationCenterService.instance.markAllAsRead();
                          },
                          child: const Text(
                            'Mark all read',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentEmerald),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.campaign_outlined, color: textColor, size: 22),
                          tooltip: 'View All Announcements',
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            AnnouncementsSheet.show(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              Expanded(
                child: StreamBuilder<List<AppNotification>>(
                  stream: NotificationCenterService.instance.stream,
                  initialData: NotificationCenterService.instance.currentNotifications,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accentEmerald.withOpacity(0.12),
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 30,
                                  color: AppColors.accentEmerald,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No recent alerts',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Attendance updates, messages, homework tasks, and announcements will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: subtextColor, height: 1.4),
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetCtx);
                                  AnnouncementsSheet.show(context);
                                },
                                icon: const Icon(Icons.campaign_outlined, size: 16),
                                label: const Text('Open Announcements'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final notif = items[idx];
                        IconData icon = Icons.notifications_rounded;
                        Color iconColor = AppColors.accentEmerald;
                        if (notif.type.contains('message')) {
                          icon = Icons.chat_bubble_rounded;
                          iconColor = AppColors.accentTealLight;
                        } else if (notif.type.contains('payment')) {
                          icon = Icons.receipt_long_rounded;
                          iconColor = AppColors.accentAmber;
                        } else if (notif.type.contains('homework')) {
                          icon = Icons.menu_book_rounded;
                          iconColor = const Color(0xFF8B5CF6);
                        } else if (notif.type.contains('attendance') || notif.type.contains('absence')) {
                          icon = Icons.fact_check_rounded;
                          iconColor = AppColors.accentEmerald;
                        }

                        return InkWell(
                          onTap: () => NotificationCenterService.instance.markAsRead(notif.id),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: notif.isRead ? borderColor : iconColor.withOpacity(0.45),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, size: 18, color: iconColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notif.title,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                          if (!notif.isRead)
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: iconColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        notif.body,
                                        style: TextStyle(fontSize: 12, color: subtextColor, height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
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
