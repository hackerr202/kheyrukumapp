import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

/// Telegram-style Chat Screen with:
/// - Distinct Telegram-like chat bubble layout (received vs sent)
/// - Genuine native media attachment pickers (Camera, Gallery, Video, Document/PDF)
/// - Direct cloud upload to Supabase Storage
/// - Real hardware microphone voice recording using `record` (AAC .m4a format)
/// - Real streaming voice playback using `audioplayers.AudioPlayer` with interactive progress
/// - Clickable document bubbles opening files via `url_launcher`
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

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
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

  // Media uploading state
  bool _isUploadingAttachment = false;

  String get _currentUserId => AuthSessionService.instance.userId;
  String get _currentUserName => AuthSessionService.instance.userName;
  String get _currentUserRole => AuthSessionService.instance.currentRole;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();

    // Setup audio player event subscriptions
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

  // --- Real Voice Message Recording ---

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required to record voice notes.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/voice_${widget.conversationId}_$timestamp.m4a';
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
          SnackBar(content: Text('Could not start recording: ${SupabaseService.cleanErrorMessage(e)}')),
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

      // Upload audio file to Supabase Storage bucket 'voice_messages'
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
              content: Text('Failed to upload voice recording to cloud storage.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error sending voice note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice recording: ${SupabaseService.cleanErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
      _currentRecordingPath = null;
    }
  }

  // --- Real Streaming Voice Playback ---

  Future<void> _togglePlayVoice(ChatMessage msg) async {
    final url = msg.attachmentUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice audio URL is not available.'),
          behavior: SnackBarBehavior.floating,
        ),
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

  // --- Real Native Device Media Attachment Pickers ---

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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach image: ${SupabaseService.cleanErrorMessage(e)}')),
        );
      }
      debugPrint('[ChatScreen] Error picking image: $e');
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach video: ${SupabaseService.cleanErrorMessage(e)}')),
        );
      }
      debugPrint('[ChatScreen] Error picking video: $e');
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
      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach document: ${SupabaseService.cleanErrorMessage(e)}')),
        );
      }
      debugPrint('[ChatScreen] Error picking document: $e');
    }
  }

  void _showAttachmentSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share Attachment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFFE11D48),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendImage(source: ImageSource.camera);
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendImage(source: ImageSource.gallery);
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendVideo();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendDocument();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.auto_stories_rounded,
                      label: 'Ayah Quote',
                      color: AppColors.accentEmerald,
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendQuranAyahQuote();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _sendQuranAyahQuote() {
    _sendMessage(
      type: 'text',
      contentOverride: '📖 Surah Al-Kahf (18:10): "Our Lord, grant us from Yourself mercy and prepare for us from our affair right guidance."',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: cardBg,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accentEmerald.withOpacity(0.2),
              child: Icon(
                widget.targetRole == 'teacher'
                    ? Icons.menu_book_rounded
                    : (widget.targetRole == 'parent' ? Icons.person_rounded : Icons.groups_rounded),
                color: AppColors.accentEmerald,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversationTitle,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.accentEmerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('online', style: TextStyle(fontSize: 11, color: AppColors.accentEmerald)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stream of messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: MessagingService.instance.streamMessages(widget.conversationId),
              initialData: MessagingService.instance.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 24, color: subtextColor),
                          const SizedBox(height: 6),
                          Text(
                            'Messages are end-to-end encrypted & direct.',
                            style: TextStyle(color: subtextColor, fontSize: 11.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Send a greeting or voice note to begin.',
                            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _currentUserId;

                    return _buildTelegramMessageBubble(
                      msg: msg,
                      isMe: isMe,
                      isDark: isDark,
                      textColor: textColor,
                      subtextColor: subtextColor,
                    );
                  },
                );
              },
            ),
          ),

          // Uploading Attachment Progress Bar
          if (_isUploadingAttachment)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.accentEmerald.withOpacity(0.12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentEmerald),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Uploading attachment to cloud...',
                    style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // Bottom Telegram Input Bar or Voice Recording Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: SafeArea(
              child: _isRecordingVoice
                  ? _buildVoiceRecordingBar()
                  : _buildStandardInputBar(textColor, subtextColor, isDark, borderColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardInputBar(Color textColor, Color subtextColor, bool isDark, Color borderColor) {
    return Row(
      children: [
        // Attachment button (clip)
        IconButton(
          icon: const Icon(Icons.attach_file_rounded, size: 22),
          color: subtextColor,
          onPressed: _isUploadingAttachment ? null : () => _showAttachmentSheet(context),
        ),

        // Text input field
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(22),
            ),
            child: TextField(
              controller: _msgCtrl,
              style: TextStyle(color: textColor, fontSize: 13.5),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(color: subtextColor, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Send text button OR Mic button if input is empty
        if (_msgCtrl.text.trim().isNotEmpty)
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.accentEmerald,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, size: 18, color: Colors.black),
              onPressed: _isUploadingAttachment ? null : () => _sendMessage(),
            ),
          )
        else
          GestureDetector(
            onLongPress: _startVoiceRecording,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hold mic button to record voice note, tap arrow to send.'),
                  duration: Duration(milliseconds: 1600),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentEmerald.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded, size: 22, color: AppColors.accentEmerald),
            ),
          ),
      ],
    );
  }

  Widget _buildVoiceRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          // Flashing Recording Indicator
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_recordingSeconds),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Recording microphone...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          // Cancel Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
            onPressed: _cancelVoiceRecording,
          ),
          const SizedBox(width: 4),
          // Send voice button
          Container(
            decoration: const BoxDecoration(
              color: AppColors.accentEmerald,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 20),
              onPressed: _finishAndSendVoiceRecording,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelegramMessageBubble({
    required ChatMessage msg,
    required bool isMe,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    final bubbleBg = isMe
        ? (isDark ? const Color(0xFF2E7D32).withOpacity(0.85) : const Color(0xFFD1FAE5))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final bubbleTextColor = isMe
        ? (isDark ? Colors.white : const Color(0xFF064E3B))
        : textColor;

    final timeColor = isMe
        ? (isDark ? Colors.white70 : const Color(0xFF047857))
        : subtextColor;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender name tag for received group messages
            if (!isMe) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.senderName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentEmerald,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      msg.senderRole.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: subtextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // Message Body (Voice, Image, Video, Document or Standard Text)
            if (msg.messageType == 'voice' || msg.messageType == 'audio')
              _buildVoiceBubbleContent(msg, isMe, bubbleTextColor, timeColor)
            else if (msg.messageType == 'image')
              _buildImageBubbleContent(msg, isMe, bubbleTextColor)
            else if (msg.messageType == 'video')
              _buildVideoBubbleContent(msg, isMe, bubbleTextColor)
            else if (msg.messageType == 'document')
              _buildDocumentBubbleContent(msg, isMe, bubbleTextColor)
            else
              Text(
                msg.content,
                style: TextStyle(fontSize: 13.5, color: bubbleTextColor, height: 1.3),
              ),

            const SizedBox(height: 3),

            // Timestamp + Telegram double checkmarks
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 9.5, color: timeColor),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: isDark ? AppColors.accentEmerald : const Color(0xFF059669),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceBubbleContent(ChatMessage msg, bool isMe, Color textColor, Color timeColor) {
    final isCurrentMsg = _currentlyPlayingId == msg.id;
    final isPlaying = isCurrentMsg && _playerState == PlayerState.playing;
    final durationSec = msg.audioDurationSeconds ?? 5;

    final progressRatio = isCurrentMsg && _playbackDuration.inMilliseconds > 0
        ? min(1.0, _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds)
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _togglePlayVoice(msg),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withOpacity(0.2) : AppColors.accentEmerald.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isMe ? Colors.white : AppColors.accentEmerald,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform representation reacting to real playback position
              Row(
                children: List.generate(20, (index) {
                  final heights = [10, 16, 6, 14, 22, 12, 18, 20, 8, 14, 18, 10, 22, 14, 8, 16, 12, 8, 14, 6];
                  final h = heights[index % heights.length].toDouble();
                  final barThreshold = index / 20.0;
                  final isBarActive = isCurrentMsg && progressRatio >= barThreshold;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.1),
                    width: 2.4,
                    height: h,
                    decoration: BoxDecoration(
                      color: isBarActive
                          ? (isMe ? Colors.white : AppColors.accentEmerald)
                          : textColor.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                isCurrentMsg
                    ? '${_formatDuration(_playbackPosition.inSeconds)} / ${_formatDuration(_playbackDuration.inSeconds > 0 ? _playbackDuration.inSeconds : durationSec)}'
                    : _formatDuration(durationSec),
                style: TextStyle(fontSize: 10, color: timeColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageBubbleContent(ChatMessage msg, bool isMe, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 150,
            width: double.infinity,
            color: Colors.black26,
            child: msg.attachmentUrl != null && msg.attachmentUrl!.startsWith('http')
                ? Image.network(
                    msg.attachmentUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image_rounded, size: 40, color: Colors.grey),
                  ),
          ),
        ),
        if (msg.content.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            msg.content,
            style: TextStyle(fontSize: 13, color: textColor),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoBubbleContent(ChatMessage msg, bool isMe, Color textColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
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
          color: Colors.black.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF8B5CF6), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.attachmentName ?? 'Video File',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Tap to stream / play video',
                    style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentBubbleContent(ChatMessage msg, bool isMe, Color textColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final url = msg.attachmentUrl;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not open document URL.'),
                  behavior: SnackBarBehavior.floating,
                ),
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
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.insert_drive_file_rounded, size: 24, color: Color(0xFFFFA000)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.attachmentName ?? msg.content,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Tap to view / download document',
                    style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.75)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: textColor.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }
}
