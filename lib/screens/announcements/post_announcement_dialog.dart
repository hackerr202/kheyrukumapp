import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';

/// Redesigned Modern Modal dialog for Admins to compose and broadcast real-time announcements
/// with genuine native device file picker and Supabase Storage uploads.
class PostAnnouncementDialog extends StatefulWidget {
  const PostAnnouncementDialog({super.key});

  @override
  State<PostAnnouncementDialog> createState() => _PostAnnouncementDialogState();
}

class _PostAnnouncementDialogState extends State<PostAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late final TextEditingController _authorController;

  String _selectedAudience = 'all';
  bool _isPinned = false;
  bool _isBroadcasting = false;
  String? _errorMessage;

  // Real device media & storage state
  String? _attachmentName;
  String? _attachmentUrl;
  int? _attachmentSize;
  bool _isUploadingAttachment = false;

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
    _authorController.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Pick file directly from device storage and upload to Supabase Storage
  Future<void> _pickAndUploadAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'webp', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final fileName = pickedFile.name;
      final fileBytes = pickedFile.bytes ??
          (pickedFile.path != null ? await File(pickedFile.path!).readAsBytes() : null);

      if (fileBytes == null) {
        setState(() => _errorMessage = 'Could not read selected file data from device.');
        return;
      }

      setState(() {
        _isUploadingAttachment = true;
        _errorMessage = null;
      });

      final uploadedUrl = await StorageService.uploadAnnouncementAttachment(
        fileName: fileName,
        bytes: fileBytes,
      );

      if (!mounted) return;

      if (uploadedUrl != null) {
        setState(() {
          _attachmentName = fileName;
          _attachmentUrl = uploadedUrl;
          _attachmentSize = pickedFile.size;
          _isUploadingAttachment = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attached "$fileName" from device successfully! 📎'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isUploadingAttachment = false;
          _errorMessage = 'Cloud upload failed. Please check network connection and try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAttachment = false;
        _errorMessage = 'Failed to select file: ${SupabaseService.cleanErrorMessage(e)}';
      });
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachmentName = null;
      _attachmentUrl = null;
      _attachmentSize = null;
    });
  }

  Future<void> _handleBroadcast() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      setState(() => _errorMessage = 'Please provide both title and circular text.');
      return;
    }

    setState(() {
      _isBroadcasting = true;
      _errorMessage = null;
    });

    try {
      final res = await AnnouncementService.instance.broadcastAnnouncement(
        title: title,
        content: content,
        targetAudience: _selectedAudience,
        authorName: _authorController.text.trim(),
        isPinned: _isPinned,
        attachmentUrl: _attachmentUrl,
        attachmentName: _attachmentName,
      );

      if (!mounted) return;

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = SupabaseService.cleanErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBroadcasting = false);
      }
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

              const SizedBox(height: 16),

              // Native Device File Upload Section
              Text(
                'ATTACHMENT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),

              if (_isUploadingAttachment)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: subtleBorder),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: limeGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Uploading attachment to cloud storage...',
                          style: TextStyle(fontSize: 12.5, color: textColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_attachmentUrl != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: limeGreen.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: limeGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.insert_drive_file_rounded, color: limeGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachmentName ?? 'Attached File',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (_attachmentSize != null) ...[
                                  Text(
                                    _formatFileSize(_attachmentSize!),
                                    style: TextStyle(fontSize: 11, color: subtextColor),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Ready to Broadcast',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFEF4444)),
                        onPressed: _removeAttachment,
                        tooltip: 'Remove Attachment',
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: _pickAndUploadAttachment,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: subtleBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.upload_file_rounded, size: 20, color: limeGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Upload Document / Media from Device',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

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
                      onPressed: (_isBroadcasting || _isUploadingAttachment) ? null : _handleBroadcast,
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
