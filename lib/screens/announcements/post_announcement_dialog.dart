import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/theme/app_colors.dart';

/// Redesigned Modern Modal dialog for Admins to compose and broadcast real-time announcements
/// with quick attachment/URL pasting and clean aesthetic (no cluttered categories).
class PostAnnouncementDialog extends StatefulWidget {
  const PostAnnouncementDialog({super.key});

  @override
  State<PostAnnouncementDialog> createState() => _PostAnnouncementDialogState();
}

class _PostAnnouncementDialogState extends State<PostAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _attachmentUrlController = TextEditingController();
  late final TextEditingController _authorController;

  String _selectedAudience = 'all';
  bool _isPinned = false;
  bool _isBroadcasting = false;
  String? _errorMessage;
  bool _showAttachmentField = false;

  @override
  void initState() {
    super.initState();
    final name = AuthSessionService.instance.userName;
    _authorController = TextEditingController(
      text: name.isNotEmpty ? '$name (Director)' : 'Center Administration',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _attachmentUrlController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _showAttachmentField = true;
        _attachmentUrlController.text = data.text!.trim();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted attachment link from clipboard! 📎'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleBroadcast() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final attachment = _attachmentUrlController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      setState(() => _errorMessage = 'Please provide both title and circular text.');
      return;
    }

    setState(() {
      _isBroadcasting = true;
      _errorMessage = null;
    });

    final res = await AnnouncementService.instance.broadcastAnnouncement(
      title: title,
      content: content,
      targetAudience: _selectedAudience,
      authorName: _authorController.text.trim(),
      isPinned: _isPinned,
      attachmentUrl: attachment.isNotEmpty ? attachment : null,
      attachmentName: attachment.isNotEmpty ? 'Attached Document' : null,
    );

    if (!mounted) return;
    setState(() => _isBroadcasting = false);

    if (res['success'] == true) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement broadcasted to all users successfully! 📢'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = res['error'] ?? 'Broadcast failed. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final subtleBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    const limeGreen = Color(0xFFC9F24A);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: limeGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: limeGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Broadcast Circular',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Push notice to parents & teachers',
                            style: TextStyle(fontSize: 11.5, color: subtextColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, size: 20, color: subtextColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Title Field
              Text(
                'CIRCULAR TITLE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor),
                decoration: InputDecoration(
                  hintText: 'e.g. Ramadan Recitation Schedule & Timings',
                  hintStyle: TextStyle(color: subtextColor.withOpacity(0.6), fontSize: 13),
                  filled: true,
                  fillColor: fieldBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: limeGreen, width: 1.5)),
                ),
              ),

              const SizedBox(height: 16),

              // Body Content Field
              Text(
                'MESSAGE CONTENT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _contentController,
                maxLines: 4,
                style: TextStyle(fontSize: 13.5, color: textColor, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Write the complete circular text here...',
                  hintStyle: TextStyle(color: subtextColor.withOpacity(0.6), fontSize: 13),
                  filled: true,
                  fillColor: fieldBg,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: limeGreen, width: 1.5)),
                ),
              ),

              const SizedBox(height: 14),

              // Attachment Pasting Section
              if (!_showAttachmentField)
                InkWell(
                  onTap: _pasteFromClipboard,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: subtleBorder, style: BorderStyle.solid),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.attachment_rounded, size: 18, color: subtextColor),
                        const SizedBox(width: 8),
                        Text(
                          'Paste Document / Media Link from Clipboard',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ATTACHMENT URL / DOCUMENT',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.5),
                        ),
                        InkWell(
                          onTap: _pasteFromClipboard,
                          child: const Text('Paste from clipboard', style: TextStyle(fontSize: 11, color: limeGreen, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _attachmentUrlController,
                      style: TextStyle(fontSize: 13, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'https://... or file document link',
                        prefixIcon: const Icon(Icons.link_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () => _attachmentUrlController.clear(),
                        ),
                        filled: true,
                        fillColor: fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subtleBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subtleBorder)),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 14),

              // Target Audience Selector
              Text(
                'TARGET AUDIENCE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildAudienceChip('all', 'Everyone', Icons.groups_rounded, limeGreen, textColor, fieldBg, subtleBorder),
                  const SizedBox(width: 8),
                  _buildAudienceChip('parents', 'Parents Only', Icons.family_restroom_rounded, limeGreen, textColor, fieldBg, subtleBorder),
                  const SizedBox(width: 8),
                  _buildAudienceChip('teachers', 'Teachers Only', Icons.school_rounded, limeGreen, textColor, fieldBg, subtleBorder),
                ],
              ),

              const SizedBox(height: 12),

              // Pin to Top Checkbox
              InkWell(
                onTap: () => setState(() => _isPinned = !_isPinned),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        color: _isPinned ? limeGreen : subtextColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pin this circular to the top of Home screen',
                        style: TextStyle(fontSize: 12.5, color: _isPinned ? textColor : subtextColor),
                      ),
                    ],
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: subtleBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isBroadcasting ? null : _handleBroadcast,
                      icon: _isBroadcasting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.send_rounded, size: 16, color: Colors.black),
                      label: Text(
                        _isBroadcasting ? 'Broadcasting...' : 'Broadcast Notice',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: limeGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudienceChip(
    String id,
    String label,
    IconData icon,
    Color activeColor,
    Color textColor,
    Color fieldBg,
    Color subtleBorder,
  ) {
    final isSelected = _selectedAudience == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedAudience = id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.18) : fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? activeColor : subtleBorder),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? activeColor : textColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
