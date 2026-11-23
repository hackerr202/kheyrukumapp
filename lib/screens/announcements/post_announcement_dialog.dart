import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/pro_ui_kit.dart';

/// Flagship Modal Dialog for Admins to compose and broadcast real-time circulars
/// with native device image/document pickers and Supabase Storage uploads.
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

  Future<void> _pickAndUploadAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'png',
          'jpg',
          'jpeg',
          'webp',
          'txt'
        ],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final fileName = pickedFile.name;
      final fileBytes = pickedFile.bytes ??
          (pickedFile.path != null
              ? await File(pickedFile.path!).readAsBytes()
              : null);

      if (fileBytes == null) {
        setState(
            () => _errorMessage = 'Could not read selected file from device.');
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
            content: Text('Attached "$fileName" successfully.'),
            backgroundColor: AppColors.of(context).success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isUploadingAttachment = false;
          _errorMessage =
              'Cloud upload failed. Please check network connection and try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAttachment = false;
        _errorMessage =
            'Failed to select file: ${SupabaseService.cleanErrorMessage(e)}';
      });
    }
  }

  Future<void> _pickImageAttachment() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final fileBytes = await picked.readAsBytes();
      final fileName = picked.name;

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
          _attachmentSize = fileBytes.length;
          _isUploadingAttachment = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attached photo "$fileName" successfully.'),
            backgroundColor: AppColors.of(context).success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isUploadingAttachment = false;
          _errorMessage =
              'Cloud upload failed. Please check network connection and try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAttachment = false;
        _errorMessage =
            'Failed to pick image: ${SupabaseService.cleanErrorMessage(e)}';
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
      setState(
          () => _errorMessage = 'Please provide both title and circular text.');
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
          SnackBar(
            content: const Text(
              'Announcement broadcasted to all users successfully.',
            ),
            backgroundColor: AppColors.of(context).success,
          ),
        );
      } else {
        setState(() {
          _errorMessage = res['error'] ??
              res['message'] ??
              'Broadcast failed. Please check your connection.';
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
    final p = AppColors.of(context);

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: p.gold.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.campaign_rounded,
                            color: p.gold, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Broadcast Circular',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            'Push notice to parents & teachers',
                            style: TextStyle(
                                fontSize: 11.5, color: p.inkSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: p.inkSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Text(
                'CIRCULAR TITLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.inkMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
                decoration: const InputDecoration(
                  hintText: 'e.g. Ramadan Recitation Schedule & Timings',
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'MESSAGE CONTENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.inkMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _contentController,
                maxLines: 4,
                style: TextStyle(fontSize: 13.5, color: p.ink, height: 1.4),
                decoration: const InputDecoration(
                  hintText: 'Write the complete circular text here...',
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'ATTACHMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.inkMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),

              if (_isUploadingAttachment)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: p.surfaceSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Uploading attachment to cloud storage...',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: p.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_attachmentUrl != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.surfaceSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.primary.withOpacity(0.45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: p.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isImage(_attachmentUrl!, _attachmentName)
                                  ? Icons.image_rounded
                                  : Icons.insert_drive_file_rounded,
                              color: p.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _attachmentName ?? 'Attached File',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (_attachmentSize != null) ...[
                                      Text(
                                        _formatFileSize(_attachmentSize!),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: p.inkSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      'Ready',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: p.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: p.danger),
                            onPressed: _removeAttachment,
                            tooltip: 'Remove Attachment',
                          ),
                        ],
                      ),
                      if (_isImage(_attachmentUrl!, _attachmentName)) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            color: p.canvas,
                            child: ProSignedImage(
                              mediaRef: _attachmentUrl!,
                              fit: BoxFit.cover,
                              errorWidget: const Center(
                                child: Icon(Icons.image_not_supported_rounded,
                                    color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImageAttachment,
                        icon: Icon(Icons.add_photo_alternate_rounded,
                            size: 19, color: p.primary),
                        label: const Text('Attach Photo',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickAndUploadAttachment,
                        icon: Icon(Icons.attach_file_rounded,
                            size: 19, color: p.primary),
                        label: const Text('Attach File',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              Text(
                'TARGET AUDIENCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.inkMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildAudienceChip(p, 'all', 'Everyone', Icons.groups_rounded),
                  const SizedBox(width: 8),
                  _buildAudienceChip(
                      p, 'parents', 'Parents', Icons.family_restroom_rounded),
                  const SizedBox(width: 8),
                  _buildAudienceChip(
                      p, 'teachers', 'Teachers', Icons.school_rounded),
                ],
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: () => setState(() => _isPinned = !_isPinned),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        color: _isPinned ? p.gold : p.inkMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pin this circular to the top of Home screen',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                _isPinned ? FontWeight.w600 : FontWeight.w400,
                            color: _isPinned ? p.ink : p.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: p.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: (_isBroadcasting || _isUploadingAttachment)
                          ? null
                          : _handleBroadcast,
                      icon: _isBroadcasting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        _isBroadcasting ? 'Broadcasting...' : 'Broadcast',
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
    AppPalette p,
    String id,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedAudience == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedAudience = id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? p.primarySoft : p.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? p.primary : p.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? p.primary : p.inkSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? p.primary : p.ink,
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

  bool _isImage(String url, String? name) {
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
}
