import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/announcement.dart';
import '../../core/services/announcement_service.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/pro_ui_kit.dart';

/// Flagship Modal Dialog for Admins to compose, edit, and broadcast real-time
/// circulars with native device image/document pickers and Supabase Storage uploads.
class PostAnnouncementDialog extends StatefulWidget {
  final Announcement? existingAnnouncement;

  const PostAnnouncementDialog({super.key, this.existingAnnouncement});

  @override
  State<PostAnnouncementDialog> createState() => _PostAnnouncementDialogState();
}

class _PostAnnouncementDialogState extends State<PostAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _authorController = TextEditingController();

  String _selectedAudience = 'all';
  bool _isPinned = false;
  bool _isBroadcasting = false;
  String? _errorMessage;

  String? _attachmentName;
  String? _attachmentUrl;
  int? _attachmentSize;
  bool _isUploadingAttachment = false;
  bool _didInitLocalizedDefaults = false;

  bool get _isEditing => widget.existingAnnouncement != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAnnouncement;
    if (existing != null) {
      _titleController.text = existing.title;
      _contentController.text = existing.content;
      _authorController.text = existing.authorName;
      _selectedAudience = existing.targetAudience;
      _isPinned = existing.isPinned;
      _attachmentUrl = existing.attachmentUrl;
      _attachmentName = existing.attachmentName;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      if (!_isEditing) {
        final loc = AppLocalizations.of(context);
        final name = AuthSessionService.instance.userName;
        _authorController.text = name.isNotEmpty
            ? '$name (${loc.translate('directorRoleShort')})'
            : loc.translate('centerAdministrationTitle');
      }
    }
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

      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      if (fileBytes == null) {
        setState(() =>
            _errorMessage = loc.translate('couldNotReadSelectedFileMsg'));
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
            content: Text(loc.tr('attachedFileSuccessMsg', {'name': fileName})),
            backgroundColor: AppColors.of(context).success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isUploadingAttachment = false;
          _errorMessage = loc.translate('cloudUploadFailedMsg');
        });
      }
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      setState(() {
        _isUploadingAttachment = false;
        _errorMessage = loc.tr('failedSelectFileMsg', {
          'error': SupabaseService.cleanErrorMessage(e),
        });
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
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
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
            content:
                Text(loc.tr('attachedPhotoSuccessMsg', {'name': fileName})),
            backgroundColor: AppColors.of(context).success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isUploadingAttachment = false;
          _errorMessage = loc.translate('cloudUploadFailedMsg');
        });
      }
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      setState(() {
        _isUploadingAttachment = false;
        _errorMessage = loc.tr('failedPickImageMsg', {
          'error': SupabaseService.cleanErrorMessage(e),
        });
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
    final loc = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      setState(() => _errorMessage = loc.translate('provideTitleAndContentMsg'));
      return;
    }

    setState(() {
      _isBroadcasting = true;
      _errorMessage = null;
    });

    try {
      final res = _isEditing
          ? await AnnouncementService.instance.updateAnnouncement(
              id: widget.existingAnnouncement!.id,
              title: title,
              content: content,
              targetAudience: _selectedAudience,
              authorName: _authorController.text.trim(),
              isPinned: _isPinned,
              attachmentUrl: _attachmentUrl,
              attachmentName: _attachmentName,
            )
          : await AnnouncementService.instance.broadcastAnnouncement(
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
        final messenger = ScaffoldMessenger.of(context);
        final successColor = AppColors.of(context).success;
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? loc.translate('announcementUpdatedMsg')
                  : loc.translate('announcementBroadcastedMsg'),
            ),
            backgroundColor: successColor,
          ),
        );
      } else {
        setState(() {
          _errorMessage = res['offline'] == true
              ? loc.translate('offlineActionRequiredMsg')
              : (res['error']?.toString() ??
                  res['message']?.toString() ??
                  loc.translate('broadcastFailedMsg'));
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
    final loc = AppLocalizations.of(context);

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
                        child: Icon(
                            _isEditing
                                ? Icons.edit_note_rounded
                                : Icons.campaign_rounded,
                            color: p.gold,
                            size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? loc.translate('editAnnouncementAction')
                                : loc.translate('broadcastCircularTitle'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            loc.translate('pushNoticeSubtitle'),
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
                loc.translate('circularTitleHeader'),
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
                decoration: InputDecoration(
                  hintText: loc.translate('circularTitleHint'),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                loc.translate('messageContentHeader'),
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
                decoration: InputDecoration(
                  hintText: loc.translate('messageContentHint'),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                loc.translate('attachmentHeader'),
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
                          loc.translate('uploadingAttachmentCloudMsg'),
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
                                  _attachmentName ??
                                      loc.translate('attachedFileFallback'),
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
                                      loc.translate('readyStatusTag'),
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
                            tooltip: loc.translate('removeAttachmentTooltip'),
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
                        label: Text(loc.translate('attachPhotoAction'),
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickAndUploadAttachment,
                        icon: Icon(Icons.attach_file_rounded,
                            size: 19, color: p.primary),
                        label: Text(loc.translate('attachFileAction'),
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              Text(
                loc.targetAudience,
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
                  _buildAudienceChip(
                    p,
                    'all',
                    loc.everyone,
                    Icons.groups_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildAudienceChip(
                    p,
                    'parents',
                    loc.parentsOnly,
                    Icons.family_restroom_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildAudienceChip(
                    p,
                    'teachers',
                    loc.teachersOnly,
                    Icons.school_rounded,
                  ),
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
                          loc.translate('pinCircularLabel'),
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
                      child: Text(AppLocalizations.of(context).cancel),
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
                          : Icon(
                              _isEditing
                                  ? Icons.save_rounded
                                  : Icons.send_rounded,
                              size: 16),
                      label: Text(
                        _isBroadcasting
                            ? AppLocalizations.of(context).loading
                            : (_isEditing
                                ? loc.translate('saveChanges')
                                : AppLocalizations.of(context).postAnnouncement),
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
