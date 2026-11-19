import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/announcement.dart';
import '../../core/models/app_notification.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/notification_center_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/pro_ui_kit.dart';
import '../payments/payments_screen.dart';
import 'post_announcement_dialog.dart';

/// Modal bottom sheet showing:
/// - Real-time student alerts & notifications
/// - Official center announcements with functional audience/pinned/attachment filters
class AnnouncementsSheet extends StatefulWidget {
  const AnnouncementsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AnnouncementsSheet(),
    );
  }

  @override
  State<AnnouncementsSheet> createState() => _AnnouncementsSheetState();
}

class _AnnouncementsSheetState extends State<AnnouncementsSheet> {
  int _activeTab = 0; // 0: Alerts, 1: Notices
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isAdmin = AuthSessionService.instance.isAdmin;

    return ProBottomSheetShell(
      title: 'Notices & Activity',
      subtitle: 'School circulars and account updates',
      icon: Icons.campaign_rounded,
      iconColor: p.gold,
      heightFactor: 0.88,
      trailingAction: _activeTab == 0
          ? TextButton(
              onPressed: () =>
                  NotificationCenterService.instance.markAllAsRead(),
              child: const Text('Mark read', style: TextStyle(fontSize: 12)),
            )
          : (isAdmin
              ? ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const PostAnnouncementDialog(),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Post', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.gold,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                )
              : null),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: ProSegmentedControl(
              labels: const ['Activity Alerts', 'Announcements'],
              selectedIndex: _activeTab,
              onChanged: (idx) => setState(() => _activeTab = idx),
            ),
          ),

          if (_activeTab == 0)
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: NotificationCenterService.instance.stream,
                initialData:
                    NotificationCenterService.instance.currentNotifications,
                builder: (context, snapshot) {
                  final notifs = snapshot.data ?? [];

                  if (notifs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: ProEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No alerts yet',
                          message:
                              'Daily attendance updates, weekly reports, and tuition reminders will appear here.',
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    itemCount: notifs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(notifs[index], p);
                    },
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
                  _buildFilterChip('all', 'All Notices', p),
                  _buildFilterChip('pinned', 'Pinned', p),
                  _buildFilterChip('parents', 'Parents', p),
                  _buildFilterChip('teachers', 'Teachers', p),
                  _buildFilterChip('attachments', 'Attachments', p),
                ],
              ),
            ),
            Divider(height: 8, color: p.border),
            Expanded(
              child: StreamBuilder<List<Announcement>>(
                stream: AnnouncementService.instance.streamAnnouncements(),
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
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: ProEmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'No notices found',
                          message:
                              'No center announcements match the selected filter.',
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
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: p.ink,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(item.createdAt),
                      style: TextStyle(color: p.inkMuted, fontSize: 10.5),
                    ),
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
                if (isPaymentType) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaymentsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Open Tuition & Payments →',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.primary,
                        fontWeight: FontWeight.w700,
                      ),
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
      padding: const EdgeInsets.only(right: 8),
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
              Wrap(
                spacing: 6,
                children: [
                  ProStatusPill(
                    label: 'Official Notice',
                    icon: Icons.campaign_rounded,
                    color: p.primary,
                  ),
                  if (item.isPinned)
                    ProStatusPill(
                      label: 'Pinned',
                      icon: Icons.push_pin_rounded,
                      color: p.gold,
                    ),
                ],
              ),
              Text(
                _formatDate(item.createdAt),
                style: TextStyle(color: p.inkMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: TextStyle(
              color: p.ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.content,
            style: TextStyle(
              color: p.inkSecondary,
              fontSize: 12.5,
              height: 1.45,
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
                    color: p.surfaceSubtle,
                    constraints: const BoxConstraints(maxHeight: 220),
                    width: double.infinity,
                    child: Image.network(
                      item.attachmentUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return SizedBox(
                          height: 150,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.primary,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.broken_image_rounded,
                                size: 20, color: p.inkMuted),
                            const SizedBox(width: 8),
                            Text(
                              'Image unavailable',
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
                  final uri = Uri.tryParse(item.attachmentUrl!);
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
                          item.attachmentName ?? 'Attached document',
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
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: p.inkMuted),
              const SizedBox(width: 5),
              Text(
                item.authorName,
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
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
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.goldWarm,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
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
