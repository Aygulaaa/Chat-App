import 'dart:async';
import 'dart:io';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/mime_utils.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/providers/message_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/reply_quote.dart';
import 'package:image_picker/image_picker.dart';

class MessageInput extends ConsumerStatefulWidget {
  final int chatId;
  final bool isBlocked;

  /// The message being replied to — renders the "Replying to…" bar.
  final Message? replyingTo;
  final String replyAuthorLabel;
  final VoidCallback? onCancelReply;

  const MessageInput({
    super.key,
    required this.chatId,
    this.isBlocked = false,
    this.replyingTo,
    this.replyAuthorLabel = '',
    this.onCancelReply,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  // Matches the server's multer limit — fail instantly instead of after
  // uploading 50MB over mobile data.
  static const int _maxFileBytes = 50 * 1024 * 1024;

  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecorderInitialized = false;

  bool _isRecording = false;
  String? _recordedPath;
  Timer? _recordTimer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    try {
      final recorder = FlutterSoundRecorder();
      await recorder.openRecorder();
      // The screen may have been closed while the recorder was opening —
      // calling setState then throws.
      if (!mounted) {
        await recorder.closeRecorder();
        return;
      }
      _audioRecorder = recorder;
      setState(() => _isRecorderInitialized = true);
    } catch (e) {
      debugPrint('Recorder init failed: $e');
    }
  }

  @override
  void didUpdateWidget(MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Picking a message to reply to should put the cursor in the box
    if (widget.replyingTo != null &&
        widget.replyingTo?.id != oldWidget.replyingTo?.id) {
      _focusNode.requestFocus();
    }
  }

  bool _tooLarge(int bytes) {
    if (bytes <= _maxFileBytes) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Files can be up to 50 MB')));
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recordTimer?.cancel();
    if (_isRecorderInitialized) {
      _audioRecorder?.closeRecorder();
      _audioRecorder = null;
    }
    super.dispose();
  }

  String _getCleanErrorMessage(dynamic e) =>
      ErrorHandler.getReadableErrorMessage(e);

  /// Hands a picked file to the send queue. Nothing here waits for the
  /// upload: the bubble appears at once with its own progress bar, and the
  /// input stays free for typing (the old spinner blocked the whole row).
  Future<void> _enqueue(
    Future<Uint8List> Function() read,
    String name, {
    String? path,
    int? knownSize,
  }) async {
    if (knownSize != null && _tooLarge(knownSize)) return;
    final bytes = await read();
    if (!mounted || bytes.isEmpty || _tooLarge(bytes.length)) return;

    final mimeType = MimeUtils.getMimeType(name.split('.').last);
    ref
        .read(messageProvider(widget.chatId).notifier)
        .sendFileMessage(bytes, name, mimeType, localPath: path);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getCleanErrorMessage(e))));
      }
    }
  }

  Future<void> _takePhoto() => _guard(() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo == null) return;
    await _enqueue(photo.readAsBytes, photo.name, path: photo.path);
  });

  /// Several photos / videos at once — they queue up and upload in order.
  Future<void> _pickMedia() => _guard(() async {
    final picked = await ImagePicker().pickMultipleMedia(limit: 20);
    for (final file in picked) {
      if (!mounted) return;
      await _enqueue(file.readAsBytes, file.name, path: file.path);
    }
  });

  Future<void> _pickFiles() => _guard(() async {
    final files = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    for (final file in files) {
      if (!mounted) return;
      await _enqueue(
        file.readAsBytes,
        file.name,
        path: file.path,
        knownSize: await file.length(),
      );
    }
  });

  void _showAttachSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) {
        Widget option(IconData icon, Color color, String label, VoidCallback go) {
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(sheet).pop();
                go();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.16),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                option(
                  Icons.photo_library_rounded,
                  const Color(0xFF3D8EF0),
                  'Gallery',
                  _pickMedia,
                ),
                option(
                  Icons.camera_alt_rounded,
                  const Color(0xFFF2554D),
                  'Camera',
                  _takePhoto,
                ),
                option(
                  Icons.insert_drive_file_rounded,
                  const Color(0xFF3DBD63),
                  'File',
                  _pickFiles,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission denied — enable it in Settings',
            ),
          ),
        );
      }
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder!.startRecorder(toFile: path, codec: Codec.aacMP4);

      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordedPath = null;
          _recordDuration = 0;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getCleanErrorMessage(e))));
      }
    }
  }

  void _startTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_recordDuration >= 180) {
        _stopRecording();
      } else {
        setState(() => _recordDuration++);
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    if (!_isRecording || !_isRecorderInitialized) return;

    try {
      final path = await _audioRecorder!.stopRecorder();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordedPath = path;
        });
      }
    } catch (e) {
      debugPrint('❌ Recording stop error: $e');
    }
  }

  void _deleteRecording() {
    setState(() {
      _recordedPath = null;
      _recordDuration = 0;
    });
  }

  Future<void> _sendRecording() async {
    if (_recordedPath == null) return;
    try {
      final file = File(_recordedPath!);
      final exists = await file.exists();

      if (!exists) return;

      final length = await file.length();
      if (length < 1000) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      final filename = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await ref
          .read(messageProvider(widget.chatId).notifier)
          .sendFileMessage(bytes, filename, 'audio/mp4');

      if (mounted) {
        setState(() {
          _recordedPath = null;
          _recordDuration = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getCleanErrorMessage(e))));
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    if (_isRecorderInitialized && _isRecording) {
      await _audioRecorder!.stopRecorder();
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
      _recordedPath = null;
    });
  }

  void _onSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    final message = Message(
      id: DateTime.now().microsecondsSinceEpoch,
      chatId: widget.chatId,
      senderId: user.id,
      text: text,
      createdAt: DateTime.now(),
    );

    HapticFeedback.lightImpact();
    ref
        .read(messageProvider(widget.chatId).notifier)
        .sendMessageFunction(message);

    _controller.clear();
  }

  Widget _buildBlockedBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.block_rounded, size: 16.sp, color: context.textTertiary),
        SizedBox(width: 8.w),
        Flexible(
          child: Text(
            'You blocked this user. Unblock to send messages.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textTertiary, fontSize: 13.sp),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyBar(BuildContext context) {
    final target = widget.replyingTo;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: target == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.fromLTRB(10.w, 0, 0, 8.h),
              child: Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 20.sp,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ReplyQuote(
                      reply: ReplyPreview.fromMessage(target),
                      authorLabel: 'Reply to ${widget.replyAuthorLabel}',
                      filled: false,
                      onClose: widget.onCancelReply,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(5.w, 8.h, 5.w, 8.h),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.glassBorder, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: context.isLight
                ? Colors.black.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      // SafeArea keeps the bar clear of the home indicator / gesture pill
      child: SafeArea(
        top: false,
        child: widget.isBlocked
            ? Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                child: _buildBlockedBar(context),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildReplyBar(context),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_isRecording)
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: AppColors.error,
                            size: 22.sp,
                          ),
                          onPressed: _cancelRecording,
                        )
                      else if (_recordedPath != null)
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: AppColors.error,
                            size: 22.sp,
                          ),
                          onPressed: _deleteRecording,
                        )
                      else
                        // One attach button → sheet (gallery multi-select,
                        // camera, files). No spinner here any more: upload
                        // progress lives on each message bubble.
                        Padding(
                          padding: EdgeInsets.only(right: 4.w),
                          child: IconButton(
                            tooltip: 'Attach',
                            icon: Icon(
                              Icons.add_circle_outline_rounded,
                              color: context.textTertiary,
                              size: 26.sp,
                            ),
                            onPressed: _showAttachSheet,
                          ),
                        ),

                      Expanded(
                        child: _isRecording
                            ? _RecordingIndicator(duration: _recordDuration)
                            : _recordedPath != null
                            ? Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14.w),
                                child: Text(
                                  'Audio recorded: ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 15.sp,
                                  ),
                                ),
                              )
                            : TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                // Grows with the text up to 5 lines, then scrolls —
                                // it was a single line that scrolled sideways.
                                minLines: 1,
                                maxLines: 5,
                                maxLength: 4000,
                                buildCounter:
                                    (
                                      _, {
                                      required currentLength,
                                      required isFocused,
                                      required maxLength,
                                    }) => null,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (val) => ref
                                    .read(
                                      messageProvider(widget.chatId).notifier,
                                    )
                                    .sendTypingEvent(val.isNotEmpty),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15.sp,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Message...',
                                  hintStyle: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 15.sp,
                                  ),
                                  filled: true,
                                  fillColor: context.cardBg,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 10.h,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22.r),
                                    borderSide: BorderSide(
                                      color: context.glassBorder,
                                      width: 0.8,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22.r),
                                    borderSide: BorderSide(
                                      color: context.glassBorder,
                                      width: 0.8,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(22.r),
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                      ),

                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (_, value, _) {
                          final hasText = value.text.trim().isNotEmpty;
                          final Widget button = _buildTrailingButton(
                            context,
                            hasText,
                          );
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOutBack,
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                            child: button,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTrailingButton(BuildContext context, bool hasText) {
    if (_isRecording) {
      return IconButton(
        key: const ValueKey('stop'),
        icon: Icon(Icons.stop_circle, color: AppColors.primary, size: 30.sp),
        onPressed: _stopRecording,
      );
    }

    if (_recordedPath != null) {
      return IconButton(
        key: const ValueKey('send-audio'),
        icon: Icon(Icons.send_rounded, color: AppColors.primary, size: 22.sp),
        onPressed: _sendRecording,
      );
    }

    if (hasText) {
      return IconButton(
        key: const ValueKey('send'),
        icon: Icon(Icons.send_rounded, color: AppColors.primary, size: 22.sp),
        onPressed: _onSend,
      );
    }

    return IconButton(
      key: const ValueKey('mic'),
      icon: Icon(Icons.mic_rounded, color: context.textTertiary, size: 22.sp),
      onPressed: _startRecording,
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  final int duration;

  const _RecordingIndicator({required this.duration});

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.duration ~/ 60;
    final sec = widget.duration % 60;
    final formattedTime = '$min:${sec.toString().padLeft(2, '0')}';

    return Row(
      children: [
        const SizedBox(width: 12),
        FadeTransition(
          opacity: _opacity,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Recording... $formattedTime',
          style: TextStyle(color: context.textSecondary, fontSize: 14.sp),
        ),
      ],
    );
  }
}
