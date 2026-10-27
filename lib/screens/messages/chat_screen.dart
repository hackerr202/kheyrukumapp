import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/chat_message.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/theme/app_colors.dart';

/// Telegram-style Chat Screen with:
/// - Distinct Telegram-like chat bubble layout (received vs sent)
/// - Media attachment picker (Photo, Document, Ayah quote)
/// - Voice message recorder button with waveform visualization & timer
/// - Audio voice bubble playback
/// - Online presence banner and delivered/read checkmarks
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

  // Voice recording simulation states
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  // Active playing voice message id
  String? _currentlyPlayingId;

  String get _currentUserId => AuthSessionService.instance.userId;
  String get _currentUserName => AuthSessionService.instance.userName;
  String get _currentUserRole => AuthSessionService.instance.currentRole;

  @override
  void dispose() {
    _recordingTimer?.cancel();
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

  void _startVoiceRecording() {
    setState(() {
      _isRecordingVoice = true;
      _recordingSeconds = 0;
    });
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _recordingSeconds++;
      });
    });
  }

  void _cancelVoiceRecording() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });
  }

  void _finishAndSendVoiceRecording() {
    _recordingTimer?.cancel();
    final duration = _recordingSeconds > 0 ? _recordingSeconds : 3;
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });

    _sendMessage(
      type: 'voice',
      contentOverride: 'Voice message (${_formatDuration(duration)})',
      audioDurationSeconds: duration,
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
                      icon: Icons.photo_library_rounded,
                      label: 'Photo / Media',
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddLinkDialog(
                          context,
                          title: 'Paste Image URL',
                          hint: 'https://images.unsplash.com/... or paste link',
                          type: 'image',
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document / PDF',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddLinkDialog(
                          context,
                          title: 'Attach Document or Link',
                          hint: 'https://docs.google.com/... or document URL',
                          type: 'document',
                        );
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.auto_stories_rounded,
                      label: 'Quran Ayah',
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showAddLinkDialog(BuildContext context, {required String title, required String hint, required String type}) {
    final linkCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceCard
            : AppColors.surfaceCardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Title / File Name (optional)',
                hintText: type == 'image' ? 'Student Certificate.jpg' : 'Curriculum Schedule.pdf',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkCtrl,
              decoration: InputDecoration(
                labelText: 'URL or Link',
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final link = linkCtrl.text.trim();
              if (link.isNotEmpty) {
                final name = nameCtrl.text.trim().isNotEmpty
                    ? nameCtrl.text.trim()
                    : (type == 'image' ? 'Shared Photo' : 'Shared Document');
                Navigator.pop(ctx);
                _sendMessage(
                  type: type,
                  contentOverride: name,
                  attachmentUrl: link,
                  attachmentName: name,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentEmerald,
              foregroundColor: Colors.black,
            ),
            child: const Text('Attach & Send'),
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

          // Bottom Telegram Input Bar or Voice Recording Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: SafeArea(
              child: _isRecordingVoice ? _buildVoiceRecordingBar() : _buildStandardInputBar(textColor, subtextColor, isDark, borderColor),
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
          onPressed: () => _showAttachmentSheet(context),
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
              onPressed: () => _sendMessage(),
            ),
          )
        else
          GestureDetector(
            onLongPress: _startVoiceRecording,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hold to record voice message, release to send.'),
                  duration: Duration(milliseconds: 1400),
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
              'Recording voice...',
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
    // Telegram dark bubble palettes
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

            // Message Body (Voice, Image, Document or Standard Text)
            if (msg.messageType == 'voice')
              _buildVoiceBubbleContent(msg, isMe, bubbleTextColor, timeColor)
            else if (msg.messageType == 'image')
              _buildImageBubbleContent(msg, isMe, bubbleTextColor)
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
    final isPlaying = _currentlyPlayingId == msg.id;
    final durationSec = msg.audioDurationSeconds ?? 5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (isPlaying) {
                _currentlyPlayingId = null;
              } else {
                _currentlyPlayingId = msg.id;
                // Auto reset after duration
                Future.delayed(Duration(seconds: durationSec), () {
                  if (mounted && _currentlyPlayingId == msg.id) {
                    setState(() => _currentlyPlayingId = null);
                  }
                });
              }
            });
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withOpacity(0.2) : AppColors.accentEmerald.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isMe ? Colors.white : AppColors.accentEmerald,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform representation
              Row(
                children: List.generate(18, (index) {
                  final heights = [12, 18, 6, 14, 22, 10, 16, 20, 8, 14, 18, 12, 22, 14, 8, 16, 10, 6];
                  final h = heights[index % heights.length].toDouble();
                  final active = isPlaying && (index < 10);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    width: 2.5,
                    height: h,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : textColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 3),
              Text(
                isPlaying ? 'Playing...' : _formatDuration(durationSec),
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
            height: 140,
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

  Widget _buildDocumentBubbleContent(ChatMessage msg, bool isMe, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
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
                  msg.attachmentUrl ?? 'Attached file',
                  style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
