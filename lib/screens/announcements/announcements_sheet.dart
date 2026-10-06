import 'package:flutter/material.dart';
import '../../core/models/announcement.dart';
import '../../core/services/announcement_service.dart';
import 'post_announcement_dialog.dart';

/// Modal bottom sheet showing all official announcements with real-time updates.
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
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    const Text(
                      'Announcements',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined, size: 48, color: Color(0xFF475569)),
                        SizedBox(height: 10),
                        Text('No announcements found', style: TextStyle(color: Color(0xFF64748B))),
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
        selectedColor: const Color(0xFF00BCD4).withOpacity(0.2),
        backgroundColor: const Color(0xFF1E293B),
        side: BorderSide(
          color: isSelected ? const Color(0xFF00BCD4) : const Color(0xFF334155),
        ),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF00BCD4) : const Color(0xFF94A3B8),
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
