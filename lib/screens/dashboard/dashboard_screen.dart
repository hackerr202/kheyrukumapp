import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/announcement.dart';
import '../../core/models/app_notification.dart';
import '../../core/models/chat_message.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/absence_service.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/halaqah_service.dart';
import '../../core/services/homework_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/notification_center_service.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/prayer_reminder_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/student_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/hijri_date_helper.dart';
import '../../widgets/announcement_banner.dart';
import '../../widgets/kheyrukum_nav_bar.dart';
import '../../widgets/offline_status_banner.dart';
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
  late final ValueNotifier<int> _unreadTotalNotifier =
      ValueNotifier<int>(_unreadNotificationsCount);
  final ValueNotifier<int> _unreadMessagesNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _messagesNewChatTrigger = ValueNotifier<int>(0);
  final ValueNotifier<Announcement?> _activeAlertNotifier =
      ValueNotifier<Announcement?>(null);
  Timer? _alertDismissTimer;
  StreamSubscription<Announcement>? _alertSub;
  StreamSubscription<List<Announcement>>? _announcementsSub;
  StreamSubscription<List<AppNotification>>? _notifsSub;
  StreamSubscription<Map<String, String>>? _prayerSub;
  StreamSubscription<List<Conversation>>? _conversationsSub;
  StreamSubscription<Map<String, dynamic>>? _notifTapSub;
  StreamSubscription<void>? _reconnectedSub;

  void _updateUnreadTotal() {
    _unreadTotalNotifier.value =
        _unreadAnnouncementsCount + _unreadNotificationsCount;
  }

  @override
  void initState() {
    super.initState();

    _initOfflineAndCloudServices();
    _recomputeUnreadMessages();
    PushNotificationService.instance.requestNotificationPermissions();

    _notifTapSub = PushNotificationService.instance.onNotificationTap
        .listen(_handleNotificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending =
          PushNotificationService.instance.consumePendingNavigationIntent();
      if (pending != null && mounted) {
        _handleNotificationTap(pending);
      }
    });

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
      _unreadAnnouncementsCount = unread;
      _updateUnreadTotal();
    });

    // 3. Stream unread system notifications
    _notifsSub = NotificationCenterService.instance.stream.listen((list) {
      if (!mounted) return;
      _unreadNotificationsCount =
          NotificationCenterService.instance.unreadCount;
      _updateUnreadTotal();
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
      final loc = AppLocalizations.of(context);
      _triggerAlertToast(Announcement(
        id: 'prayer-${DateTime.now().millisecondsSinceEpoch}',
        title: alert['title'] ?? loc.timeForPrayerDefault,
        content: alert['body'] ?? loc.prayerReminderBodyDefault,
        targetAudience: 'all',
        authorName: loc.adhanPrayerReminderTitle,
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
      _unreadMessagesNotifier.value = total;
    }
  }

  Future<void> _initOfflineAndCloudServices() async {
    final uid = AuthSessionService.instance.userId.isNotEmpty
        ? AuthSessionService.instance.userId
        : (SupabaseService.instance.currentUser?.id ?? '');

    await NotificationCenterService.instance.loadForCurrentUser();

    if (uid.isNotEmpty) {
      OfflineSyncService.instance.onBatchSynced = (syncedTypes) {
        if (!mounted) return;
        unawaited(() async {
          if (syncedTypes.contains(OfflineEntityTypes.student) ||
              syncedTypes.contains(OfflineEntityTypes.attendance) ||
              syncedTypes.contains(OfflineEntityTypes.weeklyReport)) {
            await StudentService.instance.refreshAll();
          }
          if (syncedTypes.contains(OfflineEntityTypes.homeworkAssignment) ||
              syncedTypes.contains(OfflineEntityTypes.homeworkSubmission)) {
            await HomeworkService.instance.refreshAll();
          }
          if (syncedTypes.contains(OfflineEntityTypes.absenceRequest)) {
            await AbsenceService.instance.refreshAll();
          }
          if (syncedTypes.contains(OfflineEntityTypes.chatMessage)) {
            await MessagingService.instance.refreshAndSubscribe();
          }
          if (syncedTypes.contains(OfflineEntityTypes.paymentReceipt)) {
            await PaymentService.instance.refresh();
          }
          if (syncedTypes.contains(OfflineEntityTypes.announcement)) {
            await AnnouncementService.instance.fetchFromCloud();
          }
          _recomputeUnreadMessages();
        }());
      };

      await OfflineSyncService.instance.initializeForUser(uid);
    }

    _reconnectedSub?.cancel();
    _reconnectedSub = ConnectivityService.instance.onReconnected.listen((_) {
      unawaited(() async {
        final active =
            await AuthSessionService.instance.syncFromSupabaseProfile();
        if (!active && mounted && SupabaseService.instance.currentUser == null) {
          Navigator.of(context, rootNavigator: true)
              .pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
          return;
        }
        await OfflineSyncService.instance.syncPendingMutations();
        await _bootstrapCloudServices();
      }());
    });

    await _bootstrapCloudServices();
  }

  Future<void> _bootstrapCloudServices() async {
    await AuthSessionService.instance.syncFromSupabaseProfile();
    // Phase A: Critical primary workspace data (circles, students, announcements)
    await Future.wait([
      HalaqahService.instance.fetchHalaqahs(),
      StudentService.instance.refreshAll(),
      AnnouncementService.instance.refreshAndSubscribe(),
    ]);
    if (!mounted) return;
    // Stagger secondary cloud syncs so mobile 4G sockets & UI frames avoid startup saturation
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await Future.wait([
      HomeworkService.instance.refreshAll(),
      AbsenceService.instance.refreshAll(),
      MessagingService.instance.refreshAndSubscribe(),
      PaymentService.instance.refreshAndSubscribe(),
      PushNotificationService.instance.registerDeviceToken(),
    ]);
    _recomputeUnreadMessages();
  }

  void _triggerAlertToast(Announcement announcement) {
    _alertDismissTimer?.cancel();
    _activeAlertNotifier.value = announcement;

    _alertDismissTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) _activeAlertNotifier.value = null;
    });
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    final hasConversation =
        data['conversation_id']?.toString().isNotEmpty == true;
    int targetTab = _currentTabIndex;
    if (type == 'message' || hasConversation) {
      targetTab = 2;
    } else if (type.startsWith('homework')) {
      targetTab = 3;
    } else if (type == 'attendance' || type.startsWith('absence')) {
      targetTab = 1;
    } else if (type.startsWith('payment')) {
      targetTab = 4;
    } else if (type == 'announcement' || type == 'broadcast') {
      targetTab = 0;
    }

    final nav = AppRoutes.navigatorKey.currentState;
    nav?.popUntil((route) =>
        route.settings.name == AppRoutes.dashboard || route.isFirst);

    if (targetTab != _currentTabIndex && mounted) {
      setState(() => _currentTabIndex = targetTab);
    }
  }

  @override
  void dispose() {
    PrayerReminderService.instance.stop();
    _alertDismissTimer?.cancel();
    _alertSub?.cancel();
    _announcementsSub?.cancel();
    _notifsSub?.cancel();
    _prayerSub?.cancel();
    _conversationsSub?.cancel();
    _notifTapSub?.cancel();
    _reconnectedSub?.cancel();
    _unreadTotalNotifier.dispose();
    _unreadMessagesNotifier.dispose();
    _messagesNewChatTrigger.dispose();
    _activeAlertNotifier.dispose();
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
    MessagesTab(newChatTrigger: _messagesNewChatTrigger),
    const HomeworkTab(),
    const MoreTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, _, __) {
        final p = AppColors.of(context);
        final loc = AppLocalizations.of(context);

        return Scaffold(
          backgroundColor: p.canvas,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Context-Aware Editorial App Header
                    ValueListenableBuilder<String>(
                      valueListenable:
                          AuthSessionService.instance.roleNotifier,
                      builder: (context, currentRole, _) {
                        final userName = AuthSessionService.instance.userName;
                        final avatarUrl = AuthSessionService.instance.avatarUrl;
                        final displayName = userName.isNotEmpty
                            ? userName
                            : loc.administratorTitle;
                        final isSuperAdmin = currentRole == 'superadmin';
                        final isAdmin = currentRole == 'admin' || isSuperAdmin;
                        final roleLabel = isSuperAdmin
                            ? loc.roleSuperadmin
                            : (isAdmin
                                ? loc.roleAdmin
                                : (currentRole == 'teacher'
                                    ? loc.roleTeacher
                                    : loc.roleParent));
                        final roleColor = isSuperAdmin
                            ? p.gold
                            : (isAdmin
                                ? p.gold
                                : (currentRole == 'teacher'
                                    ? p.primary
                                    : p.info));

                        String? pageTitle;
                        if (_currentTabIndex == 1) {
                          pageTitle = loc.studentRoster;
                        } else if (_currentTabIndex == 2) {
                          pageTitle = loc.navMessages;
                        } else if (_currentTabIndex == 3) {
                          pageTitle = loc.navHomework;
                        } else if (_currentTabIndex == 4) {
                          pageTitle = loc.navMore;
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (pageTitle != null)
                                    Expanded(
                                      child: Text(
                                        pageTitle,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: p.ink,
                                          letterSpacing: -0.4,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  else ...[
                                    ProAvatar(
                                      name: displayName,
                                      imageUrl: avatarUrl,
                                      radius: 21,
                                      color: roleColor,
                                      showGoldRing: isAdmin,
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            loc.tr('assalamuAlaikumUser', {
                                              'name': displayName
                                                  .trim()
                                                  .split(RegExp(r'\s+'))
                                                  .first,
                                            }),
                                            style: TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w700,
                                              color: p.ink,
                                              letterSpacing: -0.3,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: roleColor.withValues(
                                                  alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: roleColor.withValues(
                                                    alpha: 0.28),
                                              ),
                                            ),
                                            child: Text(
                                              roleLabel,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: roleColor,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (_currentTabIndex == 2) ...[
                                    InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _messagesNewChatTrigger.value++;
                                      },
                                      borderRadius: BorderRadius.circular(18),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: p.primary,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_rounded,
                                              size: 16,
                                              color: p.onPrimary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              loc.translate('newShortButton'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: p.onPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  // Notification Bell
                                  ValueListenableBuilder<int>(
                                    valueListenable: _unreadTotalNotifier,
                                    builder: (context, totalUnread, _) {
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          _HeaderIconButton(
                                            icon: Icons
                                                .notifications_none_rounded,
                                            tooltip: loc.schoolAnnouncements,
                                            onTap: () {
                                              AnnouncementService.instance
                                                  .markAllAsRead();
                                              _unreadAnnouncementsCount = 0;
                                              _updateUnreadTotal();
                                              AnnouncementsSheet.show(
                                                context,
                                                initialTab: 0,
                                              );
                                            },
                                          ),
                                          if (totalUnread > 0)
                                            PositionedDirectional(
                                              top: -4,
                                              end: -4,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 2,
                                                ),
                                                constraints:
                                                    const BoxConstraints(
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
                                                    totalUnread > 9
                                                        ? '9+'
                                                        : '$totalUnread',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _HeaderIconButton(
                                    icon: Icons.settings_outlined,
                                    tooltip: loc.portalSettings,
                                    onTap: () => SettingsSheet.show(context),
                                  ),
                                ],
                              ),
                              if (pageTitle == null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.nights_stay_outlined,
                                      size: 13,
                                      color: p.gold,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        '${HijriDateHelper.format(DateTime.now(), loc)} • ${loc.formatTodayDateBanner()}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: p.inkSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    const OfflineStatusBanner(),

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
              ValueListenableBuilder<Announcement?>(
                valueListenable: _activeAlertNotifier,
                builder: (context, activeAlert, _) {
                  if (activeAlert == null) return const SizedBox.shrink();
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnnouncementBanner(
                      announcement: activeAlert,
                      onTap: () {
                        _activeAlertNotifier.value = null;
                        AnnouncementsSheet.show(context, initialTab: 1);
                      },
                      onDismiss: () {
                        _activeAlertNotifier.value = null;
                      },
                    ),
                  );
                },
              ),

              // Bottom Fade Scrim + Floating Frosted-Glass Pill Dock
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.35, 0.72, 1.0],
                              colors: [
                                p.canvas.withOpacity(0.0),
                                p.canvas.withOpacity(0.86),
                                p.canvas,
                                p.canvas,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: ValueListenableBuilder<int>(
                          valueListenable: _unreadMessagesNotifier,
                          builder: (context, unreadMessages, _) {
                            final navItems = [
                              KheyrukumNavItem(
                                icon: Icons.home_outlined,
                                activeIcon: Icons.home_rounded,
                                label: loc.navHome,
                              ),
                              KheyrukumNavItem(
                                icon: Icons.people_outline_rounded,
                                activeIcon: Icons.people_rounded,
                                label: loc.navCircles,
                              ),
                              KheyrukumNavItem(
                                icon: Icons.chat_bubble_outline_rounded,
                                activeIcon: Icons.chat_bubble_rounded,
                                label: loc.navMessages,
                                badgeCount: unreadMessages,
                              ),
                              KheyrukumNavItem(
                                icon: Icons.assignment_turned_in_outlined,
                                activeIcon: Icons.assignment_turned_in_rounded,
                                label: loc.navHomework,
                              ),
                              KheyrukumNavItem(
                                icon: Icons.grid_view_outlined,
                                activeIcon: Icons.grid_view_rounded,
                                label: loc.navMore,
                              ),
                            ];
                            return KheyrukumNavBar(
                              selectedIndex: _currentTabIndex,
                              items: navItems,
                              onTabChanged: (index) {
                                setState(() {
                                  _currentTabIndex = index;
                                });
                              },
                            );
                          },
                        ),
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
