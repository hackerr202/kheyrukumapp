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
import '../../core/localization/app_localizations.dart';
import '../../core/models/chat_message.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/audio_waveform_widget.dart';
import '../../widgets/islamic_pattern_painter.dart';
import '../../widgets/offline_status_banner.dart';
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
  static const int _maxAttachmentBytes = 25 * 1024 * 1024;

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  // Voice recording engine
  late final AudioRecorder _audioRecorder;
  String? _currentRecordingPath;
  bool _isStartingRecording = false;
  bool _isRecordingVoice = false;
  final ValueNotifier<int> _recordingSecondsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<double>> _recordingAmplitudesNotifier =
      ValueNotifier<List<double>>(const []);
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _recordingTimer;
  String? _failedRecordingPath;
  int _failedRecordingDuration = 0;

  // Voice playback engine
  late final AudioPlayer _audioPlayer;
  String? _currentlyPlayingId;
  PlayerState _playerState = PlayerState.stopped;
  final ValueNotifier<Duration> _playbackPositionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  Duration _playbackDuration = Duration.zero;
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier<bool>(false);

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _playerPositionSub;
  StreamSubscription<Duration>? _playerDurationSub;
  StreamSubscription<void>? _playerCompleteSub;
  late Stream<List<ChatMessage>> _messagesStream;

  bool _isUploadingAttachment = false;

  String get _currentUserId => AuthSessionService.instance.userId;
  String get _currentUserName => AuthSessionService.instance.userName;
  String get _currentUserRole => AuthSessionService.instance.currentRole;

  void _onMsgTextChanged() {
    final hasText = _msgCtrl.text.trim().isNotEmpty;
    if (_hasTextNotifier.value != hasText) {
      _hasTextNotifier.value = hasText;
    }
  }

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(_onMsgTextChanged);
    _messagesStream =
        MessagingService.instance.streamMessages(widget.conversationId);
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _currentlyPlayingId = null;
          _playbackPositionNotifier.value = Duration.zero;
        }
      });
    });

    _playerPositionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      _playbackPositionNotifier.value = position;
    });

    _playerDurationSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _playbackDuration = duration);
    });

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _currentlyPlayingId = null;
      });
      _playbackPositionNotifier.value = Duration.zero;
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _messagesStream =
          MessagingService.instance.streamMessages(widget.conversationId);
    }
  }

  void _deleteTempFileAsync(String? path) {
    if (path == null || path.isEmpty) return;
    unawaited(() async {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (e) {
        debugPrint('[ChatScreen] Failed deleting temp file: $e');
      }
    }());
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _amplitudeSub?.cancel();
    _playerStateSub?.cancel();
    _playerPositionSub?.cancel();
    _playerDurationSub?.cancel();
    _playerCompleteSub?.cancel();

    _audioPlayer.dispose();
    _audioRecorder.dispose();

    _deleteTempFileAsync(_currentRecordingPath);
    _deleteTempFileAsync(_failedRecordingPath);

    _msgCtrl.removeListener(_onMsgTextChanged);
    _recordingSecondsNotifier.dispose();
    _recordingAmplitudesNotifier.dispose();
    _playbackPositionNotifier.dispose();
    _hasTextNotifier.dispose();

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

  Future<bool> _sendMessage({
    String type = 'text',
    String? contentOverride,
    String? attachmentUrl,
    String? attachmentName,
    int? audioDurationSeconds,
    String? localMediaPath,
    String? storageBucket,
    String? storagePath,
    String? mediaMimeType,
    bool showErrorSnackBar = true,
  }) async {
    final text = contentOverride ?? _msgCtrl.text.trim();
    if (text.isEmpty && attachmentUrl == null && localMediaPath == null) {
      return false;
    }
    if (contentOverride == null) _msgCtrl.clear();

    try {
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
        localMediaPath: localMediaPath,
        storageBucket: storageBucket,
        storagePath: storagePath,
        mediaMimeType: mediaMimeType,
      );

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      return true;
    } catch (e) {
      if (contentOverride == null && _msgCtrl.text.isEmpty) {
        _msgCtrl.text = text;
      }
      if (showErrorSnackBar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).tr('failedSendMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
            ),
          ),
        );
      }
      return false;
    }
  }

  // --- Voice Recording ---

  Future<void> _startVoiceRecording() async {
    if (_isStartingRecording || _isRecordingVoice || _isUploadingAttachment) {
      return;
    }
    final loc = AppLocalizations.of(context);
    _isStartingRecording = true;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('micPermissionRequiredMsg')),
            ),
          );
        }
        return;
      }
      if (!mounted) return;

      // Stop playback before opening the microphone recorder.
      await _audioPlayer.stop();
      if (!mounted) return;

      if (_failedRecordingPath != null) {
        _deleteTempFileAsync(_failedRecordingPath);
        _failedRecordingPath = null;
        _failedRecordingDuration = 0;
      }

      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;
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

      if (!mounted) {
        try {
          if (await _audioRecorder.isRecording()) {
            await _audioRecorder.stop();
          }
        } catch (_) {}
        _deleteTempFileAsync(filePath);
        _currentRecordingPath = null;
        return;
      }

      _recordingSecondsNotifier.value = 0;
      _recordingAmplitudesNotifier.value = const [];
      HapticFeedback.lightImpact();
      setState(() {
        _isRecordingVoice = true;
      });

      _amplitudeSub?.cancel();
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (!mounted || !_isRecordingVoice) return;
        final normalized = ((amp.current + 55.0) / 55.0).clamp(0.14, 1.0);
        final prev = _recordingAmplitudesNotifier.value;
        final next = prev.length >= 30
            ? [...prev.sublist(prev.length - 29), normalized]
            : [...prev, normalized];
        _recordingAmplitudesNotifier.value = next;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _recordingSecondsNotifier.value = _recordingSecondsNotifier.value + 1;
      });
    } catch (e) {
      debugPrint('[ChatScreen] Error starting voice record: $e');
      _deleteTempFileAsync(_currentRecordingPath);
      _currentRecordingPath = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.tr('couldNotStartRecordingMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
            ),
          ),
        );
      }
    } finally {
      _isStartingRecording = false;
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _recordingAmplitudesNotifier.value = const [];
    HapticFeedback.lightImpact();
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

    _recordingSecondsNotifier.value = 0;
    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _currentRecordingPath = null;
      });
    } else {
      _currentRecordingPath = null;
    }
  }

  void _retainFailedVoiceRecording(
      String filePath, int duration, String message) {
    _failedRecordingPath = filePath;
    _failedRecordingDuration = duration;
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: loc.retry,
          onPressed: _retryFailedVoiceUpload,
        ),
      ),
    );
  }

  Future<void> _retryFailedVoiceUpload() async {
    final path = _failedRecordingPath;
    if (path == null || _isUploadingAttachment || _isRecordingVoice) return;
    final duration =
        _failedRecordingDuration > 0 ? _failedRecordingDuration : 1;
    if (mounted) {
      setState(() => _isUploadingAttachment = true);
    }
    await _uploadAndSendVoiceFile(path, duration);
  }

  Future<void> _uploadAndSendVoiceFile(String filePath, int duration) async {
    final loc = AppLocalizations.of(context);
    var uploadAndSendSucceeded = false;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('voiceFileUnavailableMsg')),
            ),
          );
        }
        return;
      }

      final fileSize = await file.length();
      if (fileSize > _maxAttachmentBytes) {
        uploadAndSendSucceeded = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('voiceExceedsLimitMsg')),
            ),
          );
        }
        return;
      }

      final bytes = await file.readAsBytes();
      final ms = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voice_$ms.m4a';
      final targetPath = 'voice/${widget.conversationId}/$fileName';
      final voiceLabel = loc.tr('voiceMessageWithDuration', {
        'duration': _formatDuration(duration),
      });

      Future<void> stageAndQueueOfflineVoice() async {
        final stagedPath = await OfflineSyncService.instance.stageMediaFile(
          sourcePath: filePath,
          fileName: fileName,
        );
        final queued = await _sendMessage(
          type: 'voice',
          contentOverride: voiceLabel,
          attachmentName: fileName,
          audioDurationSeconds: duration,
          localMediaPath: stagedPath,
          storageBucket: StorageService.voiceMessagesBucket,
          storagePath: targetPath,
          mediaMimeType: 'audio/m4a',
          showErrorSnackBar: false,
        );
        if (queued) {
          uploadAndSendSucceeded = true;
          _failedRecordingPath = null;
          _failedRecordingDuration = 0;
        }
      }

      if (!ConnectivityService.instance.isOnline) {
        await stageAndQueueOfflineVoice();
        return;
      }

      final audioUrl = await StorageService.uploadVoiceNote(
        fileName: fileName,
        bytes: bytes,
        conversationId: widget.conversationId,
      );

      if (audioUrl != null) {
        final sent = await _sendMessage(
          type: 'voice',
          contentOverride: voiceLabel,
          attachmentUrl: audioUrl,
          attachmentName: fileName,
          audioDurationSeconds: duration,
          showErrorSnackBar: false,
        );
        if (sent) {
          uploadAndSendSucceeded = true;
          _failedRecordingPath = null;
          _failedRecordingDuration = 0;
          return;
        }
      }

      if (!await ConnectivityService.instance.checkNow()) {
        await stageAndQueueOfflineVoice();
        return;
      }

      _retainFailedVoiceRecording(
        filePath,
        duration,
        loc.translate('failedUploadVoiceCloudMsg'),
      );
    } catch (e) {
      debugPrint('[ChatScreen] Error sending voice note: $e');
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
        try {
          final ms = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'voice_$ms.m4a';
          final stagedPath = await OfflineSyncService.instance.stageMediaFile(
            sourcePath: filePath,
            fileName: fileName,
          );
          final queued = await _sendMessage(
            type: 'voice',
            contentOverride: loc.tr('voiceMessageWithDuration', {
              'duration': _formatDuration(duration),
            }),
            attachmentName: fileName,
            audioDurationSeconds: duration,
            localMediaPath: stagedPath,
            storageBucket: StorageService.voiceMessagesBucket,
            storagePath: 'voice/${widget.conversationId}/$fileName',
            mediaMimeType: 'audio/m4a',
            showErrorSnackBar: false,
          );
          if (queued) {
            uploadAndSendSucceeded = true;
            _failedRecordingPath = null;
            _failedRecordingDuration = 0;
            return;
          }
        } catch (_) {}
      }
      _retainFailedVoiceRecording(
        filePath,
        duration,
        'Failed to send voice recording: ${SupabaseService.cleanErrorMessage(e)}',
      );
    } finally {
      if (uploadAndSendSucceeded) {
        _deleteTempFileAsync(filePath);
      }
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
      _currentRecordingPath = null;
    }
  }

  Future<void> _finishAndSendVoiceRecording() async {
    _recordingTimer?.cancel();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _recordingAmplitudesNotifier.value = const [];
    HapticFeedback.lightImpact();
    final duration =
        _recordingSecondsNotifier.value > 0 ? _recordingSecondsNotifier.value : 1;
    _recordingSecondsNotifier.value = 0;

    setState(() {
      _isRecordingVoice = false;
      _isUploadingAttachment = true;
    });

    String? resolvedPath;
    try {
      final path = await _audioRecorder.stop();
      resolvedPath = path ?? _currentRecordingPath;
      if (resolvedPath == null) {
        if (mounted) {
          setState(() => _isUploadingAttachment = false);
        }
        _currentRecordingPath = null;
        return;
      }
      await _uploadAndSendVoiceFile(resolvedPath, duration);
    } catch (e) {
      debugPrint('[ChatScreen] Error sending voice note: $e');
      final fallbackPath = resolvedPath ?? _currentRecordingPath;
      if (fallbackPath != null) {
        _retainFailedVoiceRecording(
          fallbackPath,
          duration,
          AppLocalizations.of(context).tr('failedSendVoiceMsg', {
            'error': SupabaseService.cleanErrorMessage(e),
          }),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).tr('failedStopRecordingMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
            ),
          ),
        );
      }
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
      _currentRecordingPath = null;
    }
  }

  // --- Voice Playback ---

  Future<void> _togglePlayVoice(ChatMessage msg) async {
    final loc = AppLocalizations.of(context);
    final url = msg.attachmentUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('voiceUrlUnavailableMsg'))),
      );
      return;
    }

    try {
      final localPath = StorageService.extractLocalPath(url);
      Source audioSource;
      if (localPath != null) {
        if (!await File(localPath).exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.translate('offlineVoiceNotFoundMsg')),
              ),
            );
          }
          return;
        }
        audioSource = DeviceFileSource(localPath);
      } else {
        final resolvedUrl = await StorageService.resolveSignedUrl(url);
        if (!mounted) return;
        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.translate('couldNotAccessVoiceMsg'))),
          );
          return;
        }
        audioSource = UrlSource(resolvedUrl);
      }

      if (_currentlyPlayingId == msg.id) {
        if (_playerState == PlayerState.playing) {
          await _audioPlayer.pause();
        } else if (_playerState == PlayerState.paused) {
          await _audioPlayer.resume();
        } else {
          await _audioPlayer.play(audioSource);
        }
      } else {
        await _audioPlayer.stop();
        if (!mounted) return;
        _playbackPositionNotifier.value = Duration.zero;
        setState(() {
          _currentlyPlayingId = msg.id;
          if (msg.audioDurationSeconds != null) {
            _playbackDuration = Duration(seconds: msg.audioDurationSeconds!);
          }
        });
        await _audioPlayer.play(audioSource);
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error playing voice note: $e');
      _playbackPositionNotifier.value = Duration.zero;
      if (mounted) {
        setState(() {
          _currentlyPlayingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.tr('errorPlayingAudioMsg', {'error': '$e'}),
            ),
          ),
        );
      } else {
        _currentlyPlayingId = null;
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
    final loc = AppLocalizations.of(context);
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      final size = await picked.length();
      if (size > _maxAttachmentBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('imageExceedsLimitMsg')),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() => _isUploadingAttachment = true);

      final bytes = await picked.readAsBytes();
      final fileName = picked.name;
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final ms = DateTime.now().millisecondsSinceEpoch;
      final targetPath = 'chat/${widget.conversationId}/${ms}_$cleanName';

      Future<void> stageAndQueueOfflineImage() async {
        final stagedPath = await OfflineSyncService.instance.stageMediaBytes(
          bytes: bytes,
          fileName: cleanName,
        );
        await _sendMessage(
          type: 'image',
          contentOverride: fileName,
          attachmentName: fileName,
          localMediaPath: stagedPath,
          storageBucket: StorageService.chatAttachmentsBucket,
          storagePath: targetPath,
        );
      }

      if (!ConnectivityService.instance.isOnline) {
        await stageAndQueueOfflineImage();
        if (mounted) {
          setState(() => _isUploadingAttachment = false);
        }
        return;
      }

      final publicUrl = await StorageService.uploadChatAttachment(
        fileName: fileName,
        bytes: bytes,
        conversationId: widget.conversationId,
      );

      if (!mounted) return;
      if (publicUrl != null) {
        setState(() => _isUploadingAttachment = false);
        await _sendMessage(
          type: 'image',
          contentOverride: fileName,
          attachmentUrl: publicUrl,
          attachmentName: fileName,
        );
      } else if (!await ConnectivityService.instance.checkNow()) {
        await stageAndQueueOfflineImage();
        if (mounted) {
          setState(() => _isUploadingAttachment = false);
        }
      } else {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('failedUploadImageMsg')),
          ),
        );
      }
    } catch (e) {
      if (ConnectivityService.isNetworkError(e)) {
        ConnectivityService.instance.reportNetworkFailure();
      }
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.tr('failedAttachImageMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendVideo() async {
    final loc = AppLocalizations.of(context);
    try {
      final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      final size = await picked.length();
      if (size > _maxAttachmentBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('videoExceedsLimitMsg')),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
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
          SnackBar(
            content: Text(loc.translate('failedUploadVideoMsg')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.tr('failedAttachVideoMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendDocument() async {
    final loc = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'zip'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > _maxAttachmentBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('docExceedsLimitMsg')),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() => _isUploadingAttachment = true);

      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        if (mounted) {
          setState(() => _isUploadingAttachment = false);
        }
        return;
      }
      if (bytes.length > _maxAttachmentBytes) {
        if (mounted) {
          setState(() => _isUploadingAttachment = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('docExceedsLimitMsg')),
            ),
          );
        }
        return;
      }

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
          SnackBar(
            content: Text(loc.translate('failedUploadDocMsg')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.tr('failedAttachDocMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
            ),
          ),
        );
      }
    }
  }

  void _showAttachmentSheet(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ProBottomSheetShell(
          title: loc.shareAttachment,
          subtitle: loc.translate('shareAttachmentSubtitle'),
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
                  label: loc.translate('cameraOption'),
                  color: p.danger,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(source: ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  p: p,
                  icon: Icons.photo_library_rounded,
                  label: loc.translate('galleryOption'),
                  color: p.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(source: ImageSource.gallery);
                  },
                ),
                _buildAttachmentOption(
                  p: p,
                  icon: Icons.videocam_rounded,
                  label: loc.translate('videoOption'),
                  color: p.excused,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendVideo();
                  },
                ),
                _buildAttachmentOption(
                  p: p,
                  icon: Icons.insert_drive_file_rounded,
                  label: loc.documentAttachment,
                  color: p.success,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendDocument();
                  },
                ),
                _buildAttachmentOption(
                  p: p,
                  icon: Icons.auto_stories_rounded,
                  label: loc.translate('ayahQuoteOption'),
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
      contentOverride: AppLocalizations.of(context).translate('ayahKahf1810Quote'),
    );
  }

  void _openFullScreenImageViewer(String imageUrl, String? caption) {
    final loc = AppLocalizations.of(context);
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
                tooltip: loc.translate('openInBrowserTooltip'),
                onPressed: () async {
                  final resolvedUrl =
                      await StorageService.resolveSignedUrl(imageUrl) ?? imageUrl;
                  final uri = Uri.tryParse(resolvedUrl);
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
              child: ProSignedImage(
                mediaRef: imageUrl,
                fit: BoxFit.contain,
                placeholder: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.goldWarm,
                  ),
                ),
                errorWidget: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_rounded,
                          size: 64, color: Colors.white54),
                      const SizedBox(height: 12),
                      Text(
                        loc.translate('failedLoadImagePreview'),
                        style: const TextStyle(color: Colors.white70),
                      ),
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
    final loc = AppLocalizations.of(context);
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
                  loc.copyMessageText,
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msg.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.copiedToClipboard),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              if (isMe && (msg.messageType == 'text' || msg.messageType.isEmpty))
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: p.info),
                  title: Text(
                    loc.editMessage,
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
                    loc.deleteMessage,
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
                        title: Text('${loc.deleteMessage}?'),
                        content: Text(loc.deleteMessageConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(loc.cancel),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.danger,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(loc.delete),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await MessagingService.instance.deleteMessage(
                          conversationId: widget.conversationId,
                          messageId: msg.id,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context).tr('failedDeleteMsg', {
                                  'error': SupabaseService.cleanErrorMessage(e),
                                }),
                              ),
                              backgroundColor: p.danger,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditMessageDialog(ChatMessage msg) async {
    final p = AppColors.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => _EditMessageDialog(
        conversationId: widget.conversationId,
        message: msg,
        palette: p,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    final subtitleLabel = widget.targetRole == 'teacher'
        ? loc.translate('ustazDirectChannel')
        : (widget.targetRole == 'parent'
            ? loc.translate('parentDirectChannel')
            : (widget.targetRole == 'admin'
                ? loc.translate('centerAdministrationTitle')
                : loc.translate('centerChannel')));

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
              const OfflineStatusBanner(),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _messagesStream,
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
                                  loc.translate('directSchoolChannel'),
                                  style: TextStyle(
                                    color: p.ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loc.translate('emptyChatPrompt'),
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
                        loc.translate('uploadingAttachmentToCloud'),
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
    final loc = AppLocalizations.of(context);

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
              decoration: InputDecoration(
                filled: false,
                hintText: loc.writeMessageHint,
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
        ValueListenableBuilder<bool>(
          valueListenable: _hasTextNotifier,
          builder: (context, hasText, _) {
            if (hasText) {
              return Container(
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
              );
            }
            return GestureDetector(
              onLongPress: _startVoiceRecording,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.holdMicHint),
                    duration: const Duration(milliseconds: 1600),
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
            );
          },
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
        ValueListenableBuilder<int>(
          valueListenable: _recordingSecondsNotifier,
          builder: (context, seconds, _) {
            return Text(
              _formatDuration(seconds),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: p.danger,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiveRecordingWaveform(
                amplitudesNotifier: _recordingAmplitudesNotifier,
                activeColor: p.primary,
                inactiveColor: p.border,
                barCount: 30,
                height: 22,
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context)
                    .translate('recordingVoiceNoteLabel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: p.inkSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
      alignment:
          isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
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
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(18),
              topEnd: const Radius.circular(18),
              bottomStart: Radius.circular(isMe ? 18 : 4),
              bottomEnd: Radius.circular(isMe ? 4 : 18),
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
                        AppLocalizations.of(context)
                            .localizedRoleBadge(msg.senderRole),
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
                      AppLocalizations.of(context).translate('editedTag'),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontStyle: FontStyle.italic,
                        color: timeColor,
                      ),
                    ),
                  Builder(
                    builder: (_) {
                      final localTs = msg.timestamp.toLocal();
                      return Text(
                        '${localTs.hour.toString().padLeft(2, '0')}:${localTs.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: timeColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      );
                    },
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    ValueListenableBuilder<List<OfflineMutation>>(
                      valueListenable:
                          OfflineSyncService.instance.mutationsNotifier,
                      builder: (context, _, __) {
                        final isPending = OfflineSyncService.instance
                            .isRecordPending(
                          OfflineEntityTypes.chatMessage,
                          msg.id,
                        );
                        return Icon(
                          isPending
                              ? Icons.schedule_rounded
                              : Icons.done_all_rounded,
                          size: 14,
                          color: isPending ? timeColor : AppColors.goldWarm,
                        );
                      },
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

  Widget _buildVoiceWaveformColumn({
    required AppPalette p,
    required bool isMe,
    required bool isCurrentMsg,
    required double progressRatio,
    required Color textColor,
    required Color timeColor,
    required String durationLabel,
    required int seed,
    ValueChanged<double>? onSeek,
  }) {
    return PlaybackWaveformBar(
      progress: isCurrentMsg ? progressRatio : 0.0,
      activeColor: isMe ? AppColors.goldWarm : p.primary,
      inactiveColor: textColor.withValues(alpha: 0.32),
      durationLabel: durationLabel,
      labelColor: timeColor,
      seed: seed,
      barCount: 24,
      height: 22,
      onSeek: onSeek,
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
          child: isCurrentMsg
              ? ValueListenableBuilder<Duration>(
                  valueListenable: _playbackPositionNotifier,
                  builder: (context, playbackPosition, _) {
                    final progressRatio = _playbackDuration.inMilliseconds > 0
                        ? min(
                            1.0,
                            playbackPosition.inMilliseconds /
                                _playbackDuration.inMilliseconds,
                          )
                        : 0.0;
                    return _buildVoiceWaveformColumn(
                      p: p,
                      isMe: isMe,
                      isCurrentMsg: true,
                      progressRatio: progressRatio,
                      textColor: textColor,
                      timeColor: timeColor,
                      durationLabel:
                          '${_formatDuration(playbackPosition.inSeconds)} / ${_formatDuration(_playbackDuration.inSeconds > 0 ? _playbackDuration.inSeconds : durationSec)}',
                      seed: msg.id.hashCode,
                      onSeek: (ratio) {
                        final totalMs = _playbackDuration.inMilliseconds > 0
                            ? _playbackDuration.inMilliseconds
                            : durationSec * 1000;
                        if (totalMs <= 0) return;
                        final target = Duration(
                          milliseconds: (ratio.clamp(0.0, 1.0) * totalMs).round(),
                        );
                        _playbackPositionNotifier.value = target;
                        _audioPlayer.seek(target);
                      },
                    );
                  },
                )
              : _buildVoiceWaveformColumn(
                  p: p,
                  isMe: isMe,
                  isCurrentMsg: false,
                  progressRatio: 0.0,
                  textColor: textColor,
                  timeColor: timeColor,
                  durationLabel: _formatDuration(durationSec),
                  seed: msg.id.hashCode,
                  onSeek: (_) => _togglePlayVoice(msg),
                ),
        ),
      ],
    );
  }

  Widget _buildImageBubbleContent(
      ChatMessage msg, bool isMe, Color textColor, AppPalette p) {
    final hasValidUrl = StorageService.isValidMediaRef(msg.attachmentUrl);
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
                      ? ProSignedImage(
                          mediaRef: msg.attachmentUrl!,
                          fit: BoxFit.cover,
                          placeholder: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isMe ? Colors.white : p.primary,
                              ),
                            ),
                          ),
                          errorWidget: const Center(
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
              PositionedDirectional(
                bottom: 8,
                end: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in_rounded,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        AppLocalizations.of(context).translate('viewAction'),
                        style: const TextStyle(
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
    final loc = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final url = msg.attachmentUrl;
        if (url != null && url.isNotEmpty) {
          final resolved = await StorageService.resolveSignedUrl(url) ?? url;
          final uri = Uri.tryParse(resolved);
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
                    msg.attachmentName ?? loc.translate('videoFileFallback'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    loc.translate('tapToPlayVideo'),
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
    final loc = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final url = msg.attachmentUrl;
        if (url != null && url.isNotEmpty) {
          final resolved = await StorageService.resolveSignedUrl(url) ?? url;
          final uri = Uri.tryParse(resolved);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.translate('couldNotOpenDocUrl'))),
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
                    loc.translate('tapToViewDownload'),
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

class _EditMessageDialog extends StatefulWidget {
  final String conversationId;
  final ChatMessage message;
  final AppPalette palette;

  const _EditMessageDialog({
    required this.conversationId,
    required this.message,
    required this.palette,
  });

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _editCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.message.content);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.editMessage),
      content: TextField(
        controller: _editCtrl,
        enabled: !_isSaving,
        autofocus: true,
        maxLines: 4,
        minLines: 1,
        decoration: InputDecoration(hintText: loc.translate('enterUpdatedMsgHint')),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  final newText = _editCtrl.text.trim();
                  if (newText.isEmpty || newText == widget.message.content) {
                    if (newText == widget.message.content) {
                      Navigator.pop(context);
                    }
                    return;
                  }
                  setState(() => _isSaving = true);
                  try {
                    await MessagingService.instance.editMessage(
                      conversationId: widget.conversationId,
                      messageId: widget.message.id,
                      newContent: newText,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.tr('failedEditMsg', {
                            'error': SupabaseService.cleanErrorMessage(e),
                          }),
                        ),
                        backgroundColor: widget.palette.danger,
                      ),
                    );
                  }
                },
          child: Text(_isSaving ? loc.savingProgress : loc.save),
        ),
      ],
    );
  }
}
