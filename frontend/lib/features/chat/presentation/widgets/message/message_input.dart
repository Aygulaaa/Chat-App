import 'dart:async';
import 'dart:io';
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
import 'package:image_picker/image_picker.dart';

class MessageInput extends ConsumerStatefulWidget {
  final int chatId;
  final bool isBlocked;

  const MessageInput({
    super.key,
    required this.chatId,
    this.isBlocked = false,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  late final TextEditingController _controller;
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecorderInitialized = false;

  bool _isRecording = false;
  bool _isSendingFile = false;
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
    _audioRecorder = FlutterSoundRecorder();
    await _audioRecorder!.openRecorder();
    setState(() {
      _isRecorderInitialized = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _recordTimer?.cancel();
    if (_isRecorderInitialized) {
      _audioRecorder?.closeRecorder();
      _audioRecorder = null;
    }
    super.dispose();
  }

  String _getCleanErrorMessage(dynamic e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Network')) {
      return 'Please check your internet connection and try again.';
    } else if (msg.contains('Timeout')) {
      return 'The request took too long. Please try again.';
    } else if (msg.contains('Permission')) {
      return 'Permission denied. Please check your settings.';
    } else if (msg.contains('DioException') || msg.contains('Http')) {
      return 'Server error occurred. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _takePhotoAndSend() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) return;

      setState(() => _isSendingFile = true);

      final mimeType = MimeUtils.getMimeType(photo.name.split('.').last);

      await ref
          .read(messageProvider(widget.chatId).notifier)
          .sendFileMessage(bytes, photo.name, mimeType, localPath: photo.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_getCleanErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isSendingFile = false);
    }
  }

Future<void> _pickAndSendFile() async {
  // 1. Pick a single file using the updated 12.x API
  final PlatformFile? file = await FilePicker.pickFile(
    type: FileType.any,
  );

  // 2. Return early if the user canceled the picker
  if (file == null) return;

  // 3. Read the file bytes asynchronously (works across Mobile & Web)
  final Uint8List bytes = await file.readAsBytes();

  setState(() => _isSendingFile = true);

  try {
    // 4. Resolve MIME type and notify your Riverpod state provider
    final mimeType = MimeUtils.getMimeType(file.extension ?? '');
    await ref
        .read(messageProvider(widget.chatId).notifier)
        .sendFileMessage(
          bytes,
          file.name,
          mimeType,
          localPath: file.path,
        );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getCleanErrorMessage(e))),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSendingFile = false);
    }
  }
}

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied — enable it in Settings'),
          ),
        );
      }
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder!.startRecorder(
        toFile: path,
        codec: Codec.aacMP4,
      );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getCleanErrorMessage(e))),
        );
      }
    }
  }

  void _startTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      print('❌ Recording stop error: $e');
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

    ref
        .read(messageProvider(widget.chatId).notifier)
        .sendMessageFunction(message);

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: context.cardBg,
          border: Border(
            top: BorderSide(color: context.glassBorder, width: 0.8),
          ),
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
        child: Row(
          children: [
            if (_isRecording)
              IconButton(
                icon: Icon(Icons.close, color: AppColors.error, size: 22.sp),
                onPressed: _cancelRecording,
              )
            else if (_recordedPath != null)
              IconButton(
                icon: Icon(Icons.delete, color: AppColors.error, size: 22.sp),
                onPressed: _deleteRecording,
              )
            else
              _isSendingFile
                  ? Padding(
                      padding: EdgeInsets.all(12.r),
                      child: SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.textTertiary,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.camera_alt,
                            color: context.textTertiary,
                            size: 22.sp,
                          ),
                          onPressed: _takePhotoAndSend,
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.attach_file,
                            color: context.textTertiary,
                            size: 22.sp,
                          ),
                          onPressed: _pickAndSendFile,
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          constraints: const BoxConstraints(),
                        ),
                        SizedBox(width: 8.w),
                      ],
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
                          onChanged: (val) => ref
                              .read(messageProvider(widget.chatId).notifier)
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
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
            ),

            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, __) {
                final hasText = value.text.trim().isNotEmpty;

                if (_isRecording) {
                  return IconButton(
                    icon: Icon(
                      Icons.stop_circle,
                      color: AppColors.primary,
                      size: 30.sp,
                    ),
                    onPressed: _stopRecording,
                  );
                }

                if (_recordedPath != null) {
                  return IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                    onPressed: _sendRecording,
                  );
                }

                if (hasText) {
                  return IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                    onPressed: _onSend,
                  );
                }

                return IconButton(
                  icon: Icon(
                    Icons.mic_rounded,
                    color: context.textTertiary,
                    size: 22.sp,
                  ),
                  onPressed: _startRecording,
                );
              },
            ),
          ],
        ),
      ),
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
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }
}