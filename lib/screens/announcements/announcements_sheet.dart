import 'package:flutter/material.dart';
import '../../core/models/announcement.dart';
import '../../core/models/app_notification.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/notification_center_service.dart';
import '../../core/theme/app_colors.dart';
import '../payments/payments_screen.dart';
import 'post_announcement_dialog.dart';

/// Modal bottom sheet showing:
/// - Real-time student alerts & notifications (Daily attendance, weekly reports, tuition reminders, payment verification)
/// - Official center announcements with real-time updates.
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
  int _activeTab = 0; // 0: Notifications & Alerts, 1: Center Announcements
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E334D) : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF475569),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFF00BCD4),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Notifications & Notices',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_activeTab == 0)
                  TextButton(
                    onPressed: () {
                      NotificationCenterService.instance.markAllAsRead();
                    },
                    child: const Text('Mark All Read', style: TextStyle(fontSize: 11.5, color: Color(0xFF00BCD4))),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const PostAnnouncementDialog(),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Post', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA000),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ),

          // Tab Switcher: [ Alerts & Reports | Announcements ]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 0 ? (isDark ? const Color(0xFF0F172A) : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTab == 0
                              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'Alerts & Reports',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                              color: _activeTab == 0 ? const Color(0xFF00BCD4) : subtextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 1 ? (isDark ? const Color(0xFF0F172A) : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTab == 1
                              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'Announcements',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                              color: _activeTab == 1 ? const Color(0xFFFFA000) : subtextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // TAB 0: NOTIFICATIONS & ALERTS
          if (_activeTab == 0)
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: NotificationCenterService.instance.stream,
                initialData: NotificationCenterService.instance.currentNotifications,
                builder: (context, snapshot) {
                  final notifs = snapshot.data ?? [];

                  if (notifs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 48, color: subtextColor),
                          const SizedBox(height: 10),
                          Text('No new notifications', style: TextStyle(color: subtextColor)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    itemCount: notifs.length,
                    itemBuilder: (context, index) {
                      final item = notifs[index];
                      return _buildNotificationCard(item, isDark, cardBg, borderColor, textColor, subtextColor);
                    },
                  );
                },
              ),
            ),

          // TAB 1: ANNOUNCEMENTS
          if (_activeTab == 1) ...[
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Notices'),
                  _buildFilterChip('urgent', 'Urgent Alerts'),
                  _buildFilterChip('event', 'Quran Events'),
                  _buildFilterChip('quran_halaqah', 'Halaqah'),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 16),

            // Streamed Realtime List
            Expanded(
              child: StreamBuilder<List<Announcement>>(
                stream: AnnouncementService.instance.streamAnnouncements(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var list = snapshot.data ?? [];

                  if (_selectedFilter != 'all') {
                    list = list.where((a) => a.category == _selectedFilter).toList();
                  }

                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined, size: 48, color: subtextColor),
                          const SizedBox(height: 10),
                          Text('No announcements found', style: TextStyle(color: subtextColor)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return _buildAnnouncementCard(item);
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

  Widget _buildNotificationCard(
    AppNotification item,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    Color iconBg = const Color(0xFF00BCD4);
    IconData iconData = Icons.notifications_rounded;

    if (item.type == 'attendance') {
      iconBg = const Color(0xFF10B981);
      iconData = Icons.fact_check_rounded;
    } else if (item.type == 'weekly_report') {
      iconBg = const Color(0xFF8B5CF6);
      iconData = Icons.menu_book_rounded;
    } else if (item.type == 'payment_reminder' || item.type == 'payment_overdue') {
      iconBg = const Color(0xFFFFA000);
      iconData = Icons.payment_rounded;
    } else if (item.type == 'payment_rejection') {
      iconBg = const Color(0xFFEF4444);
      iconData = Icons.error_rounded;
    } else if (item.type == 'prayer') {
      iconBg = const Color(0xFF10B981);
      iconData = Icons.access_time_filled_rounded;
    }

    final isPaymentType = item.type.startsWith('payment');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconBg.withOpacity(0.18),
            child: Icon(iconData, color: iconBg, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                      ),
                    ),
                    Text(
                      _formatDate(item.createdAt),
                      style: TextStyle(color: subtextColor, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(fontSize: 11.5, color: subtextColor, height: 1.35),
                ),
                if (isPaymentType) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                      );
                    },
                    child: const Text(
                      'View in Payments Hub →',
                      style: TextStyle(fontSize: 11, color: Color(0xFF00BCD4), fontWeight: FontWeight.bold),
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

  Widget _buildFilterChip(String id, String label) {
    final isSelected = _selectedFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFFFA000).withOpacity(0.2),
        backgroundColor: const Color(0xFF1E293B),
        side: BorderSide(
          color: isSelected ? const Color(0xFFFFA000) : const Color(0xFF334155),
        ),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFFFFA000) : const Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => setState(() => _selectedFilter = id),
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement item) {
    Color badgeColor = const Color(0xFF00BCD4);
    String badgeLabel = 'General';

    switch (item.category) {
      case 'urgent':
        badgeColor = const Color(0xFFFF4B72);
        badgeLabel = 'URGENT ALERT';
        break;
      case 'event':
        badgeColor = const Color(0xFFFFA000);
        badgeLabel = 'QURAN EVENT';
        break;
      case 'quran_halaqah':
        badgeColor = const Color(0xFF10B981);
        badgeLabel = 'HALAQAH';
        break;
      case 'holiday':
        badgeColor = const Color(0xFFC9F24A);
        badgeLabel = 'HOLIDAY';
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161927) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isPinned
              ? const Color(0xFFFFA000).withOpacity(0.6)
              : (isDark ? const Color(0xFF23283E) : const Color(0xFFE2E8F0)),
          width: item.isPinned ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (item.isPinned) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA000).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.push_pin_rounded, size: 10, color: Color(0xFFFFA000)),
                          SizedBox(width: 3),
                          Text(
                            'PINNED',
                            style: TextStyle(
                              color: Color(0xFFFFA000),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                _formatDate(item.createdAt),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.content,
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                item.authorName,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
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
}
