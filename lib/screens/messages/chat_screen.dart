import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/chat_message.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/islamic_pattern_painter.dart';
import '../../widgets/pro_ui_kit.dart';

/// Flagship Direct & Circle Chat Screen:
/// - Refined sent/received bubbles in Deep Pine & Warm Sanctuary Ivory
/// - Native media pickers (Camera, Gallery, Video, Document/PDF, Quran Ayah Quote)
/// - Real microphone voice note recording (AAC .m4a) & streaming playback waveform
/// - Long-press Copy, Edit, and Delete actions
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String conversationTitle;
  final String? targetRole;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.conversationTitle,
    this.targetRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  // Voice recording engine
  late final AudioRecorder _audioRecorder;
  String? _currentRecordingPath;
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  // Voice playback engine
  late final AudioPlayer _audioPlayer;
  String? _currentlyPlayingId;
  PlayerState _playerState = PlayerState.stopped;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _playerPositionSub;
  StreamSubscription<Duration>? _playerDurationSub;
  StreamSubscription<void>? _playerCompleteSub;

  bool _isUploadingAttachment = false;

  String get _currentUserId => AuthSessionService.instance.userId;
  String get _currentUserName => AuthSessionService.instance.userName;
  String get _currentUserRole => AuthSessionService.instance.currentRole;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _currentlyPlayingId = null;
          _playbackPosition = Duration.zero;
        }
      });
    });

    _playerPositionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _playbackPosition = position);
    });

    _playerDurationSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _playbackDuration = duration);
    });

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _currentlyPlayingId = null;
        _playbackPosition = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playerStateSub?.cancel();
    _playerPositionSub?.cancel();
    _playerDurationSub?.cancel();
    _playerCompleteSub?.cancel();

    _audioPlayer.dispose();
    _audioRecorder.dispose();

    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage({
    String type = 'text',
    String? contentOverride,
    String? attachmentUrl,
    String? attachmentName,
    int? audioDurationSeconds,
  }) async {
    final text = contentOverride ?? _msgCtrl.text.trim();
    if (text.isEmpty && attachmentUrl == null) return;
    if (contentOverride == null) _msgCtrl.clear();

    await MessagingService.instance.sendMessage(
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      senderRole: _currentUserRole,
      content: text,
      messageType: type,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      audioDurationSeconds: audioDurationSeconds,
    );

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  // --- Voice Recording ---

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required to record voice notes.',
              ),
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath =
          '${tempDir.path}/voice_${widget.conversationId}_$timestamp.m4a';
      _currentRecordingPath = filePath;

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecordingVoice = true;
        _recordingSeconds = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _recordingSeconds++);
      });
    } catch (e) {
      debugPrint('[ChatScreen] Error starting voice record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not start recording: ${SupabaseService.cleanErrorMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
      if (_currentRecordingPath != null) {
        final f = File(_currentRecordingPath!);
        if (await f.exists()) await f.delete();
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error cancelling record: $e');
    }

    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
      _currentRecordingPath = null;
    });
  }

  Future<void> _finishAndSendVoiceRecording() async {
    _recordingTimer?.cancel();
    final duration = _recordingSeconds > 0 ? _recordingSeconds : 1;

    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
      _isUploadingAttachment = true;
    });

    try {
      final path = await _audioRecorder.stop();
      final resolvedPath = path ?? _currentRecordingPath;
      if (resolvedPath == null) return;

      final file = File(resolvedPath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final audioUrl = await StorageService.uploadVoiceNote(
        fileName: fileName,
        bytes: bytes,
        conversationId: widget.conversationId,
      );

      if (audioUrl != null) {
        await _sendMessage(
          type: 'voice',
          contentOverride: 'Voice message (${_formatDuration(duration)})',
          attachmentUrl: audioUrl,
          attachmentName: fileName,
          audioDurationSeconds: duration,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to upload voice recording to cloud storage.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error sending voice note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send voice recording: ${SupabaseService.cleanErrorMessage(e)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
      _currentRecordingPath = null;
    }
  }

  // --- Voice Playback ---

  Future<void> _togglePlayVoice(ChatMessage msg) async {
    final url = msg.attachmentUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice audio URL is not available.')),
      );
      return;
    }

    try {
      if (_currentlyPlayingId == msg.id) {
        if (_playerState == PlayerState.playing) {
          await _audioPlayer.pause();
        } else if (_playerState == PlayerState.paused) {
          await _audioPlayer.resume();
        } else {
          await _audioPlayer.play(UrlSource(url));
        }
      } else {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingId = msg.id;
          _playbackPosition = Duration.zero;
          if (msg.audioDurationSeconds != null) {
            _playbackDuration = Duration(seconds: msg.audioDurationSeconds!);
          }
        });
        await _audioPlayer.play(UrlSource(url));
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error playing voice note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // --- Media Pickers ---

  Future<void> _pickAndSendImage({required ImageSource source}) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingAttachment = true);

      final bytes = await picked.readAsBytes();
      final fileName = picked.name;
      final publicUrl = await StorageService.uploadChatAttachment(
        fileName: fileName,
        bytes: bytes,
        conversationId: widget.conversationId,
      );

      if (!mounted) return;
      setState(() => _isUploadingAttachment = false);

      if (publicUrl != null) {
        await _sendMessage(
          type: 'image',
          contentOverride: fileName,
          attachmentUrl: publicUrl,
          attachmentName: fileName,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image to cloud storage.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to attach image: ${SupabaseService.cleanErrorMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isUploadingAttachment = true);

      final bytes = await picked.readAsBytes();
      final fileName = picked.name;
      final publicUrl = await StorageService.uploadChatAttachment(
        fileName: fileName,
        bytes: bytes,
        conversationId: widget.conversationId,
      );

      if (!mounted) return;
      setState(() => _isUploadingAttachment = false);

      if (publicUrl != null) {
        await _sendMessage(
          type: 'video',
          contentOverride: fileName,
          attachmentUrl: publicUrl,
          attachmentName: fileName,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload video to cloud storage.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to attach video: ${SupabaseService.cleanErrorMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) return;

      setState(() => _isUploadingAttachment = true);

      final publicUrl = await StorageService.uploadChatAttachment(
        fileName: file.name,
        bytes: bytes,
        conversationId: widget.conversationId,
      );

      if (!mounted) return;
      setState(() => _isUploadingAttachment = false);

      if (publicUrl != null) {
        await _sendMessage(
          type: 'document',
          contentOverride: file.name,
          attachmentUrl: publicUrl,
          attachmentName: file.name,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload document to cloud storage.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to attach document: ${SupabaseService.cleanErrorMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  void _showAttachmentSheet(BuildContext context) {
    final p = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ProBottomSheetShell(
          title: 'Share Attachment',
          subtitle: 'Photos, videos, files, or Quranic reflection',
          icon: Icons.attach_file_rounded,
          iconColor: p.primary,
          heightFactor: 0.34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  p: p,
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: p.danger,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(source: ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  p: p,
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: p.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(source: ImageSource.gallery);
                  },
                ),
                _buildAttachmentOption(
                  p: p,
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: p.excused,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendVideo();
                  },
                ),
                _buildAttachmentOption(
                  p: p,
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Document',
                  color: p.success,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendDocument();
                  },
                ),
                _buildAttachmentOption(
                  p: p,
                  icon: Icons.auto_stories_rounded,
                  label: 'Ayah Quote',
                  color: p.gold,
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendQuranAyahQuote();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required AppPalette p,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.28)),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }

  void _sendQuranAyahQuote() {
    _sendMessage(
      type: 'text',
      contentOverride:
          'Surah Al-Kahf (18:10): "Our Lord, grant us from Yourself mercy and prepare for us from our affair right guidance."',
    );
  }

  void _openFullScreenImageViewer(String imageUrl, String? caption) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.75),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon:
                    const Icon(Icons.open_in_browser_rounded, color: Colors.white),
                tooltip: 'Open in browser',
                onPressed: () async {
                  final uri = Uri.tryParse(imageUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.goldWarm,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_rounded,
                          size: 64, color: Colors.white54),
                      SizedBox(height: 12),
                      Text('Failed to load image preview',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: (caption != null && caption.isNotEmpty)
              ? Container(
                  color: Colors.black.withOpacity(0.85),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: SafeArea(
                    child: Text(
                      caption,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage msg, bool isMe) {
    final p = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: p.inkMuted.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: p.primary),
                title: Text(
                  'Copy Message Text',
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msg.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              if (isMe && (msg.messageType == 'text' || msg.messageType.isEmpty))
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: p.info),
                  title: Text(
                    'Edit Message',
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditMessageDialog(msg);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: p.danger),
                  title: Text(
                    'Delete Message',
                    style: TextStyle(
                      color: p.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete Message?'),
                        content: const Text(
                          'This will remove the message for everyone in this chat.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.danger,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await MessagingService.instance.deleteMessage(
                        conversationId: widget.conversationId,
                        messageId: msg.id,
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMessageDialog(ChatMessage msg) {
    final editCtrl = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: const InputDecoration(hintText: 'Enter updated message...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = editCtrl.text.trim();
              if (newText.isNotEmpty && newText != msg.content) {
                Navigator.pop(ctx);
                await MessagingService.instance.editMessage(
                  conversationId: widget.conversationId,
                  messageId: msg.id,
                  newContent: newText,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    final subtitleLabel = widget.targetRole == 'teacher'
        ? 'Ustaz Direct Channel'
        : (widget.targetRole == 'parent'
            ? 'Parent Direct Channel'
            : (widget.targetRole == 'admin'
                ? 'Center Administration'
                : 'Center Channel'));

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: p.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: p.border),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: p.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ProAvatar(
              name: widget.conversationTitle,
              radius: 19,
              color: widget.targetRole == 'admin' ? p.gold : p.primary,
              icon: widget.targetRole == 'teacher'
                  ? Icons.menu_book_rounded
                  : (widget.targetRole == 'parent'
                      ? Icons.person_rounded
                      : Icons.groups_rounded),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversationTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitleLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: p.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: IslamicGeometricPattern(
                color: p.primary,
                opacity: p.isDark ? 0.03 : 0.035,
                cellSize: 64,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: MessagingService.instance
                      .streamMessages(widget.conversationId),
                  initialData: MessagingService.instance
                      .getMessages(widget.conversationId),
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: ProCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline_rounded,
                                    size: 26, color: p.primary),
                                const SizedBox(height: 10),
                                Text(
                                  'Direct School Channel',
                                  style: TextStyle(
                                    color: p.ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Send a message, document, photo, or voice note to begin.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: p.inkSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == _currentUserId;
                        return _buildMessageBubble(msg, isMe, p);
                      },
                    );
                  },
                ),
              ),

              if (_isUploadingAttachment)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: p.primarySoft,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Uploading attachment to cloud...',
                        style: TextStyle(
                          fontSize: 12,
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Composer Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border(top: BorderSide(color: p.border, width: 1)),
                ),
                child: SafeArea(
                  top: false,
                  child: _isRecordingVoice
                      ? _buildVoiceRecordingBar(p)
                      : _buildStandardInputBar(p),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandardInputBar(AppPalette p) {
    final hasText = _msgCtrl.text.trim().isNotEmpty;

    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.attach_file_rounded, size: 22, color: p.inkSecondary),
          onPressed:
              _isUploadingAttachment ? null : () => _showAttachmentSheet(context),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: p.surfaceSubtle,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.border),
            ),
            child: TextField(
              controller: _msgCtrl,
              style: TextStyle(color: p.ink, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                filled: false,
                hintText: 'Write a message...',
                hintStyle: TextStyle(color: p.inkMuted, fontSize: 13.5),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (hasText)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: p.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.send_rounded, size: 18, color: p.onPrimary),
              onPressed: _isUploadingAttachment ? null : () => _sendMessage(),
            ),
          )
        else
          GestureDetector(
            onLongPress: _startVoiceRecording,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hold microphone button to record a voice note.'),
                  duration: Duration(milliseconds: 1600),
                ),
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: p.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: p.primary.withOpacity(0.3)),
              ),
              child: Icon(Icons.mic_rounded, size: 21, color: p.primary),
            ),
          ),
      ],
    );
  }

  Widget _buildVoiceRecordingBar(AppPalette p) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: p.danger,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_recordingSeconds),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: p.danger,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Recording voice note...',
            style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: p.inkMuted, size: 21),
          onPressed: _cancelVoiceRecording,
        ),
        const SizedBox(width: 4),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: p.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon:
                Icon(Icons.arrow_upward_rounded, color: p.onPrimary, size: 20),
            onPressed: _finishAndSendVoiceRecording,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, AppPalette p) {
    final bubbleBg = isMe
        ? (p.isDark ? const Color(0xFF0F4F4B) : AppColors.pinePrimary)
        : p.surface;

    final bubbleTextColor = isMe ? Colors.white : p.ink;
    final timeColor = isMe ? Colors.white.withOpacity(0.75) : p.inkMuted;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isMe),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleBg,
            border: isMe ? null : Border.all(color: p.border, width: 1),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(p.isDark ? 0.22 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg.senderName,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: p.surfaceSubtle,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        msg.senderRole.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: p.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
              ],
              if (msg.messageType == 'voice' || msg.messageType == 'audio')
                _buildVoiceBubbleContent(msg, isMe, bubbleTextColor, timeColor, p)
              else if (msg.messageType == 'image')
                _buildImageBubbleContent(msg, isMe, bubbleTextColor, p)
              else if (msg.messageType == 'video')
                _buildVideoBubbleContent(msg, isMe, bubbleTextColor)
              else if (msg.messageType == 'document')
                _buildDocumentBubbleContent(msg, isMe, bubbleTextColor)
              else
                Text(
                  msg.content,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: bubbleTextColor,
                    height: 1.38,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  if (msg.isEdited)
                    Text(
                      'edited ',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontStyle: FontStyle.italic,
                        color: timeColor,
                      ),
                    ),
                  Text(
                    '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: timeColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: AppColors.goldWarm,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceBubbleContent(
    ChatMessage msg,
    bool isMe,
    Color textColor,
    Color timeColor,
    AppPalette p,
  ) {
    final isCurrentMsg = _currentlyPlayingId == msg.id;
    final isPlaying = isCurrentMsg && _playerState == PlayerState.playing;
    final durationSec = msg.audioDurationSeconds ?? 5;

    final progressRatio = isCurrentMsg && _playbackDuration.inMilliseconds > 0
        ? min(1.0,
            _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds)
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _togglePlayVoice(msg),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withOpacity(0.20)
                  : p.primary.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isMe ? Colors.white : p.primary,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(20, (index) {
                  const heights = [
                    10,
                    16,
                    7,
                    14,
                    22,
                    12,
                    18,
                    20,
                    8,
                    14,
                    18,
                    10,
                    22,
                    14,
                    8,
                    16,
                    12,
                    8,
                    14,
                    7
                  ];
                  final h = heights[index % heights.length].toDouble();
                  final barThreshold = index / 20.0;
                  final isBarActive =
                      isCurrentMsg && progressRatio >= barThreshold;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    width: 2.5,
                    height: h,
                    decoration: BoxDecoration(
                      color: isBarActive
                          ? (isMe ? AppColors.goldWarm : p.primary)
                          : textColor.withOpacity(0.32),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 5),
              Text(
                isCurrentMsg
                    ? '${_formatDuration(_playbackPosition.inSeconds)} / ${_formatDuration(_playbackDuration.inSeconds > 0 ? _playbackDuration.inSeconds : durationSec)}'
                    : _formatDuration(durationSec),
                style: TextStyle(
                  fontSize: 10.5,
                  color: timeColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageBubbleContent(
      ChatMessage msg, bool isMe, Color textColor, AppPalette p) {
    final hasValidUrl =
        msg.attachmentUrl != null && msg.attachmentUrl!.startsWith('http');
    return GestureDetector(
      onTap: () {
        if (hasValidUrl) {
          _openFullScreenImageViewer(
            msg.attachmentUrl!,
            msg.content.isNotEmpty ? msg.content : msg.attachmentName,
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 185,
                  width: double.infinity,
                  color: Colors.black12,
                  child: hasValidUrl
                      ? Image.network(
                          msg.attachmentUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isMe ? Colors.white : p.primary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded,
                                size: 36, color: Colors.grey),
                          ),
                        )
                      : const Center(
                          child:
                              Icon(Icons.image_rounded, size: 40, color: Colors.grey),
                        ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded,
                          size: 12, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (msg.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              msg.content,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoBubbleContent(
      ChatMessage msg, bool isMe, Color textColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final url = msg.attachmentUrl;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isMe ? Colors.white : AppColors.pinePrimary)
                    .withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: isMe ? Colors.white : AppColors.pinePrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.attachmentName ?? 'Video File',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Tap to play video',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: textColor.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentBubbleContent(
      ChatMessage msg, bool isMe, Color textColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final url = msg.attachmentUrl;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open document URL.')),
              );
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isMe ? Colors.white : AppColors.goldPrimary)
                    .withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                size: 22,
                color: isMe ? AppColors.goldWarm : AppColors.goldPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.attachmentName ?? msg.content,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Tap to view / download',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: textColor.withOpacity(0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: textColor.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}
