import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/announcement.dart';
import '../../core/models/app_notification.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/notification_center_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/json_parsers.dart';
import '../../widgets/pro_ui_kit.dart';
import '../payments/payments_screen.dart';
import 'post_announcement_dialog.dart';

/// Modal bottom sheet showing:
/// - Real-time student alerts & notifications
/// - Official center announcements with functional audience/pinned/attachment filters
class AnnouncementsSheet extends StatefulWidget {
  final int initialTab;

  const AnnouncementsSheet({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnnouncementsSheet(initialTab: initialTab),
    );
  }

  @override
  State<AnnouncementsSheet> createState() => _AnnouncementsSheetState();
}

class _AnnouncementsSheetState extends State<AnnouncementsSheet> {
  late int _activeTab; // 0: Alerts, 1: Notices
  String _selectedFilter = 'all';
  late final Stream<List<AppNotification>> _notificationsStream;
  late final Stream<List<Announcement>> _announcementsStream;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _notificationsStream = NotificationCenterService.instance.stream;
    _announcementsStream = AnnouncementService.instance.streamAnnouncements();
    if (_activeTab == 1) {
      AnnouncementService.instance.markAllAsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final isAdmin = AuthSessionService.instance.isAdmin;

    return ProBottomSheetShell(
      title: loc.translate('noticesAndActivityTitle'),
      subtitle: loc.translate('circularsAndAlertsSubtitle'),
      icon: Icons.campaign_rounded,
      iconColor: p.gold,
      heightFactor: 0.88,
      trailingAction: (_activeTab == 1 && isAdmin)
          ? ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const PostAnnouncementDialog(),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 15),
              label: Text(loc.translate('postShortButton'),
                  style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.gold,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            )
          : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: ProSegmentedControl(
              labels: [
                loc.translate('activityAlertsTab'),
                loc.translate('announcementsTab'),
              ],
              selectedIndex: _activeTab,
              onChanged: (idx) {
                setState(() => _activeTab = idx);
                if (idx == 1) {
                  AnnouncementService.instance.markAllAsRead();
                }
              },
            ),
          ),

          if (_activeTab == 0)
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: _notificationsStream,
                initialData:
                    NotificationCenterService.instance.currentNotifications,
                builder: (context, snapshot) {
                  final notifs = snapshot.data ?? [];

                  if (notifs.isEmpty) {
                    return Align(
                      alignment: const Alignment(0, -0.22),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ProEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: loc.translate('noAlertsYetTitle'),
                          message: loc.translate('noAlertsYetDesc'),
                        ),
                      ),
                    );
                  }

                  final hasUnread = notifs.any((n) => !n.isRead);

                  return Column(
                    children: [
                      if (hasUnread)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => NotificationCenterService
                                    .instance
                                    .markAllAsRead(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(loc.translate('markAllReadAction'),
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                          itemCount: notifs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(notifs[index], p);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          else ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                children: [
                  _buildFilterChip('all', loc.translate('allNoticesFilter'), p),
                  _buildFilterChip('pinned', loc.translate('pinnedTag'), p),
                  _buildFilterChip('parents', loc.parentsTab, p),
                  _buildFilterChip('teachers', loc.teachersTab, p),
                  _buildFilterChip(
                      'attachments', loc.translate('attachmentsFilter'), p),
                ],
              ),
            ),
            Divider(height: 8, color: p.border),
            Expanded(
              child: StreamBuilder<List<Announcement>>(
                stream: _announcementsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(color: p.primary),
                    );
                  }

                  final all = snapshot.data ?? [];
                  final list = all.where((item) {
                    switch (_selectedFilter) {
                      case 'pinned':
                        return item.isPinned;
                      case 'parents':
                        return item.targetAudience == 'parents' ||
                            item.targetAudience == 'all';
                      case 'teachers':
                        return item.targetAudience == 'teachers' ||
                            item.targetAudience == 'all';
                      case 'attachments':
                        return item.attachmentUrl != null &&
                            item.attachmentUrl!.isNotEmpty;
                      default:
                        return true;
                    }
                  }).toList();

                  if (list.isEmpty) {
                    return Align(
                      alignment: const Alignment(0, -0.22),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ProEmptyState(
                          icon: Icons.campaign_outlined,
                          title: loc.translate('noNoticesFoundTitle'),
                          message: loc.translate('noNoticesFilterDesc'),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildAnnouncementCard(list[index], p);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification item, AppPalette p) {
    final loc = AppLocalizations.of(context);
    Color iconColor = p.primary;
    IconData iconData = Icons.notifications_rounded;

    if (item.type == 'attendance') {
      iconColor = p.success;
      iconData = Icons.fact_check_rounded;
    } else if (item.type == 'weekly_report') {
      iconColor = p.excused;
      iconData = Icons.menu_book_rounded;
    } else if (item.type == 'payment_reminder' ||
        item.type == 'payment_overdue') {
      iconColor = p.gold;
      iconData = Icons.payment_rounded;
    } else if (item.type == 'payment_rejection') {
      iconColor = p.danger;
      iconData = Icons.error_rounded;
    } else if (item.type == 'prayer') {
      iconColor = p.primary;
      iconData = Icons.mosque_rounded;
    }

    final isPaymentType = item.type.startsWith('payment');

    return ProCard(
      onTap: () => NotificationCenterService.instance.markAsRead(item.id),
      borderColor: item.isRead ? p.border : iconColor.withOpacity(0.45),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(iconData, color: iconColor, size: 19),
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
                        item.title,
                        style: TextStyle(
                          fontWeight:
                              item.isRead ? FontWeight.w600 : FontWeight.w700,
                          fontSize: 13.5,
                          color: p.ink,
                        ),
                      ),
                    ),
                    Text(
                      loc.formatRelativeDate(item.createdAt),
                      style: TextStyle(
                        color: p.inkSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!item.isRead) ...[
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
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.inkSecondary,
                    height: 1.4,
                  ),
                ),
                if (isPaymentType &&
                    AuthSessionService.instance.canAccessPayments) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      final navigator = Navigator.of(context);
                      Navigator.pop(context);
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => const PaymentsScreen(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loc.translate('openTuitionPaymentsAction'),
                          style: TextStyle(
                            fontSize: 12,
                            color: p.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          size: 14,
                          color: p.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String id, String label, AppPalette p) {
    final isSelected = _selectedFilter == id;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? p.primary : p.surfaceSubtle,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? p.primary : p.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? p.onPrimary : p.inkSecondary,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement item, AppPalette p) {
    final loc = AppLocalizations.of(context);
    final hasAudienceTag =
        item.targetAudience == 'parents' || item.targetAudience == 'teachers';
    final audienceLabel =
        item.targetAudience == 'parents' ? loc.parentsTab : loc.teachersTab;

    return ProCard(
      accentStripeColor: item.isPinned ? p.gold : null,
      borderColor: item.isPinned ? p.gold.withOpacity(0.45) : p.border,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (item.isPinned || hasAudienceTag)
                Wrap(
                  spacing: 6,
                  children: [
                    if (item.isPinned)
                      ProStatusPill(
                        label: loc.translate('pinnedTag'),
                        icon: Icons.push_pin_rounded,
                        color: p.gold,
                      ),
                    if (hasAudienceTag)
                      ProStatusPill(
                        label: audienceLabel,
                        color: p.primary,
                      ),
                  ],
                )
              else
                Text(
                  loc.translate('centerNoticeTag'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: p.primary,
                    letterSpacing: 0.6,
                  ),
                ),
              Text(
                loc.formatRelativeDate(item.createdAt),
                style: TextStyle(
                  color: p.inkSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: TextStyle(
              color: p.ink,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.content,
            style: TextStyle(
              color: p.inkSecondary,
              fontSize: 13.5,
              height: 1.48,
            ),
          ),
          if (item.attachmentUrl != null &&
              item.attachmentUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (_isImageAttachment(item.attachmentUrl!, item.attachmentName))
              GestureDetector(
                onTap: () => _showFullScreenImage(item.attachmentUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    constraints: const BoxConstraints(maxHeight: 260),
                    width: double.infinity,
                    child: ProSignedImage(
                      mediaRef: item.attachmentUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      placeholder: SizedBox(
                        height: 150,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.primary,
                          ),
                        ),
                      ),
                      errorWidget: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.broken_image_rounded,
                                size: 20, color: p.inkMuted),
                            const SizedBox(width: 8),
                            Text(
                              loc.translate('imageUnavailableLabel'),
                              style: TextStyle(color: p.inkMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              InkWell(
                onTap: () async {
                  final resolved = await StorageService.resolveSignedUrl(
                          item.attachmentUrl!) ??
                      item.attachmentUrl!;
                  final uri = Uri.tryParse(resolved);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: p.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file_rounded,
                          size: 16, color: p.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.attachmentName ??
                              loc.translate('attachedDocumentFallback'),
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.open_in_new_rounded,
                          size: 15, color: p.inkMuted),
                    ],
                  ),
                ),
              ),
          ],
          if (item.authorName.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.primary.withOpacity(0.12),
                  ),
                  child: Center(
                    child: Text(
                      JsonParsers.safeInitial(item.authorName),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item.authorName == 'Center Administration'
                        ? loc.translate('centerAdministrationTitle')
                        : item.authorName.replaceAll(
                            ' (Director)',
                            ' · ${loc.translate('directorRoleShort')}',
                          ),
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 11.5,
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
  }

  bool _isImageAttachment(String url, String? name) {
    final lowerUrl = url.toLowerCase();
    final lowerName = (name ?? '').toLowerCase();
    return lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.webp') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.contains('images%2f') ||
        lowerUrl.contains('/images/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp');
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ProSignedImage(
                  mediaRef: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.goldWarm,
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 12,
              end: 12,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
