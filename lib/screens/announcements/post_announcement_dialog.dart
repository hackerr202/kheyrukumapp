import 'package:flutter/material.dart';
import '../../core/services/announcement_service.dart';

/// Modal dialog for Admins to compose and broadcast real-time announcements.
class PostAnnouncementDialog extends StatefulWidget {
  const PostAnnouncementDialog({super.key});

  @override
  State<PostAnnouncementDialog> createState() => _PostAnnouncementDialogState();
}

class _PostAnnouncementDialogState extends State<PostAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _authorController = TextEditingController(text: 'Ustaz Muhammed Yakut (Director)');

  String _selectedCategory = 'general';
  String _selectedAudience = 'all';
  bool _isPinned = false;
  bool _isBroadcasting = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _categories = const [
    {'id': 'general', 'label': 'General', 'color': Color(0xFF00BCD4)},
    {'id': 'urgent', 'label': 'Urgent Alert', 'color': Color(0xFFFF4B72)},
    {'id': 'event', 'label': 'Quran Event', 'color': Color(0xFFFFA000)},
    {'id': 'quran_halaqah', 'label': 'Halaqah Notice', 'color': Color(0xFF10B981)},
    {'id': 'holiday', 'label': 'Holiday', 'color': Color(0xFFC9F24A)},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _handleBroadcast() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      setState(() => _errorMessage = 'Please enter both title and content.');
      return;
    }

    setState(() {
      _isBroadcasting = true;
      _errorMessage = null;
    });

    final res = await AnnouncementService.instance.broadcastAnnouncement(
      title: title,
      content: content,
      category: _selectedCategory,
      targetAudience: _selectedAudience,
      authorName: _authorController.text.trim(),
      isPinned: _isPinned,
    );

    setState(() => _isBroadcasting = false);

    if (res['success'] == true) {
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement broadcasted to all users successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() => _errorMessage = res['error'] ?? 'Broadcast failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161927),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF2E334D), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA000).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Color(0xFFFFA000),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Broadcast Announcement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Instant push notification to all users',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error display
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),

            // Category Chips
            const Text(
              'Category',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final isSelected = _selectedCategory == c['id'];
                final color = c['color'] as Color;
                return ChoiceChip(
                  label: Text(c['label']),
                  selected: isSelected,
                  selectedColor: color.withOpacity(0.25),
                  backgroundColor: const Color(0xFF1E293B),
                  side: BorderSide(
                    color: isSelected ? color : const Color(0xFF334155),
                    width: isSelected ? 1.5 : 1,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? color : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = c['id']);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Target Audience
            const Text(
              'Target Audience',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildAudienceChip('all', 'All Users (Parents & Teachers)'),
                const SizedBox(width: 8),
                _buildAudienceChip('parents', 'Parents Only'),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            const Text(
              'Announcement Title',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Ramadan Recitation Competition 1448H',
                hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Content
            const Text(
              'Announcement Message',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _contentController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Write the complete announcement details here...',
                hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Pin to Top
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isPinned,
              activeColor: const Color(0xFFFFA000),
              title: const Text(
                'Pin to top of feed',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Keeps announcement prominently featured at the top',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
              onChanged: (val) => setState(() => _isPinned = val),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isBroadcasting ? null : _handleBroadcast,
                icon: _isBroadcasting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isBroadcasting ? 'Broadcasting...' : 'Broadcast Announcement',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA000),
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceChip(String id, String label) {
    final isSelected = _selectedAudience == id;
    return InkWell(
      onTap: () => setState(() => _selectedAudience = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00BCD4).withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00BCD4) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00BCD4) : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
