import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/announcement.dart';
import '../../core/models/app_notification.dart';
import '../../core/models/chat_message.dart';
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
import '../../widgets/kheyrukum_nav_bar.dart';
import '../../widgets/pro_ui_kit.dart';
import '../announcements/announcements_sheet.dart';
import '../settings/settings_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/homework_tab.dart';
import 'tabs/messages_tab.dart';
import 'tabs/more_tab.dart';
import 'tabs/students_tab.dart';

/// Main Flagship Dashboard Shell for Kheyrukum Islamic Center.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTabIndex = 0;
  int _unreadAnnouncementsCount = 0;
  int _unreadNotificationsCount = NotificationCenterService.instance.unreadCount;
  int _unreadMessagesCount = 0;
  Announcement? _activeAlertAnnouncement;
  Timer? _alertDismissTimer;
  StreamSubscription<Announcement>? _alertSub;
  StreamSubscription<List<Announcement>>? _announcementsSub;
  StreamSubscription<List<AppNotification>>? _notifsSub;
  StreamSubscription<Map<String, String>>? _prayerSub;
  StreamSubscription<List<Conversation>>? _conversationsSub;

  int get _totalUnreadCount =>
      _unreadAnnouncementsCount + _unreadNotificationsCount;

  @override
  void initState() {
    super.initState();

    _bootstrapCloudServices();
    _recomputeUnreadMessages();

    // 1. Listen for immediate popup alerts when a new announcement arrives
    _alertSub = AnnouncementService.instance.onNewAnnouncementAlert
        .listen((announcement) {
      if (!mounted) return;
      _triggerAlertToast(announcement);
    });

    // 2. Stream unread announcements count from Supabase Realtime
    _announcementsSub =
        AnnouncementService.instance.streamAnnouncements().listen((list) {
      if (!mounted) return;
      AnnouncementService.instance.registerKnownIds(list.map((a) => a.id));
      final unread =
          list.where((a) => !AnnouncementService.instance.isRead(a.id)).length;
      setState(() => _unreadAnnouncementsCount = unread);
    });

    // 3. Stream unread system notifications
    _notifsSub = NotificationCenterService.instance.stream.listen((list) {
      if (!mounted) return;
      setState(() => _unreadNotificationsCount =
          NotificationCenterService.instance.unreadCount);
    });

    // 4. Stream unread chat messages for the Messages tab badge
    _conversationsSub =
        MessagingService.instance.conversationsStream.listen((_) {
      if (!mounted) return;
      _recomputeUnreadMessages();
    });

    // 5. Start daily prayer reminder
    PrayerReminderService.instance.start();
    _prayerSub = PrayerReminderService.instance.onPrayerAlert.listen((alert) {
      if (!mounted) return;
      _triggerAlertToast(Announcement(
        id: 'prayer-${DateTime.now().millisecondsSinceEpoch}',
        title: alert['title'] ?? 'Time for Prayer',
        content:
            alert['body'] ?? 'Take a peaceful moment to remember Allah.',
        targetAudience: 'all',
        authorName: 'Adhan & Prayer Reminder',
        isPinned: true,
        createdAt: DateTime.now(),
      ));
    });
  }

  void _recomputeUnreadMessages() {
    final convos = MessagingService.instance.getConversationsForUser(
      AuthSessionService.instance.userId,
      role: AuthSessionService.instance.currentRole,
    );
    final total = convos.fold<int>(0, (sum, c) => sum + c.unreadCount);
    if (mounted) {
      setState(() => _unreadMessagesCount = total);
    }
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
    _recomputeUnreadMessages();
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
    _conversationsSub?.cancel();
    super.dispose();
  }

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
      builder: (context, _, __) {
        final p = AppColors.of(context);

        final navItems = [
          const KheyrukumNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          const KheyrukumNavItem(
            icon: Icons.people_outline_rounded,
            activeIcon: Icons.people_rounded,
            label: 'Students',
          ),
          KheyrukumNavItem(
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Messages',
            badgeCount: _unreadMessagesCount,
          ),
          const KheyrukumNavItem(
            icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book_rounded,
            label: 'Homework',
          ),
          const KheyrukumNavItem(
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: 'More',
          ),
        ];

        return Scaffold(
          backgroundColor: p.canvas,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Editorial App Header
                    ValueListenableBuilder<String>(
                      valueListenable:
                          AuthSessionService.instance.roleNotifier,
                      builder: (context, currentRole, _) {
                        final userName = AuthSessionService.instance.userName;
                        final displayName =
                            userName.isNotEmpty ? userName : 'Administrator';
                        final roleLabel = currentRole == 'admin'
                            ? 'Director'
                            : (currentRole == 'teacher' ? 'Ustaz' : 'Parent');
                        final roleColor = currentRole == 'admin'
                            ? p.gold
                            : (currentRole == 'teacher' ? p.primary : p.info);

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                          child: Row(
                            children: [
                              ProAvatar(
                                name: displayName,
                                radius: 22,
                                color: roleColor,
                                showGoldRing: currentRole == 'admin',
                              ),
                              const SizedBox(width: 12),
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
                                            color: p.inkSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: roleColor.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: roleColor.withOpacity(0.28),
                                            ),
                                          ),
                                          child: Text(
                                            roleLabel.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: roleColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 17.5,
                                        fontWeight: FontWeight.w700,
                                        color: p.ink,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Notification Bell
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _HeaderIconButton(
                                    icon: Icons.notifications_none_rounded,
                                    tooltip: 'Activity & Alerts',
                                    onTap: () =>
                                        _showUnifiedNotificationsSheet(context),
                                  ),
                                  if (_totalUnreadCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: p.danger,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: p.canvas,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _totalUnreadCount > 9
                                                ? '9+'
                                                : '$_totalUnreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              _HeaderIconButton(
                                icon: Icons.tune_rounded,
                                tooltip: 'Settings',
                                onTap: () => SettingsSheet.show(context),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Preserves tab scroll positions & live streams smoothly
                    Expanded(
                      child: IndexedStack(
                        index: _currentTabIndex,
                        children: _pages,
                      ),
                    ),
                  ],
                ),
              ),

              // Real-time Incoming Announcement Banner
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

              // Floating Frosted-Glass Pill Dock
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 14,
                child: KheyrukumNavBar(
                  selectedIndex: _currentTabIndex,
                  items: navItems,
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
    final p = AppColors.of(context);
    AnnouncementService.instance.markAllAsRead();
    setState(() => _unreadAnnouncementsCount = 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return ProBottomSheetShell(
          title: 'Activity & Alerts',
          subtitle: 'Real-time updates across your account',
          icon: Icons.notifications_active_rounded,
          iconColor: p.primary,
          heightFactor: 0.78,
          trailingAction: IconButton(
            icon: Icon(Icons.campaign_outlined, color: p.ink, size: 21),
            tooltip: 'View All Notices',
            onPressed: () {
              Navigator.pop(sheetCtx);
              AnnouncementsSheet.show(context);
            },
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECENT ACTIVITY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: p.inkMuted,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        NotificationCenterService.instance.markAllAsRead();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<AppNotification>>(
                  stream: NotificationCenterService.instance.stream,
                  initialData:
                      NotificationCenterService.instance.currentNotifications,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ProEmptyState(
                              icon: Icons.notifications_none_rounded,
                              title: 'No recent alerts',
                              message:
                                  'Attendance updates, messages, homework tasks, and school circulars will appear here.',
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                AnnouncementsSheet.show(context);
                              },
                              icon: const Icon(Icons.campaign_outlined, size: 17),
                              label: const Text('View Center Notices'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final notif = items[idx];
                        IconData icon = Icons.notifications_rounded;
                        Color iconColor = p.primary;
                        if (notif.type.contains('message')) {
                          icon = Icons.chat_bubble_rounded;
                          iconColor = p.info;
                        } else if (notif.type.contains('payment')) {
                          icon = Icons.receipt_long_rounded;
                          iconColor = p.gold;
                        } else if (notif.type.contains('homework')) {
                          icon = Icons.menu_book_rounded;
                          iconColor = p.excused;
                        } else if (notif.type.contains('attendance') ||
                            notif.type.contains('absence')) {
                          icon = Icons.fact_check_rounded;
                          iconColor = p.success;
                        }

                        return ProCard(
                          onTap: () => NotificationCenterService.instance
                              .markAsRead(notif.id),
                          padding: const EdgeInsets.all(14),
                          borderColor: notif.isRead
                              ? p.border
                              : iconColor.withOpacity(0.45),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, size: 19, color: iconColor),
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
                                              fontWeight: notif.isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.w700,
                                              color: p.ink,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(notif.createdAt),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: p.inkMuted,
                                          ),
                                        ),
                                        if (!notif.isRead) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: iconColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      notif.body,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.inkSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.month}/${dt.day}';
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Icon(icon, size: 20, color: p.ink),
          ),
        ),
      ),
    );
  }
}
