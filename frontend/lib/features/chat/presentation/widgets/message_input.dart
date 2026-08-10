import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/mime_utils.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/providers/message_notifier.dart';

class MessageInput extends ConsumerStatefulWidget {
  final int chatId;

  const MessageInput({super.key, required this.chatId});

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  late final TextEditingController _controller;
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSendingFile = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _isSendingFile = true);

    try {
      final mimeType = MimeUtils.getMimeType(file.extension ?? '');
      await ref
          .read(messageProvider(widget.chatId).notifier)
          .sendFileMessage(bytes, file.name, mimeType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send file: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSendingFile = false);
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    print("🎤 PERMISSION: $hasPermission");
    if (!hasPermission) {
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

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      final amplitude = await _recorder.getAmplitude();

print(amplitude.current);

      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      print('❌ Recording start error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      if (mounted) setState(() => _isRecording = false);

      if (path == null) {
        print('❌ Recording path is null');
        return;
      }

      print('🎙️ Recording saved to: $path');

      await Future.delayed(const Duration(seconds: 1));

      final file = File(path);
      final exists = await file.exists();

      print('📁 Exists: $exists');

      if (!exists) {
        print('❌ File missing');
        return;
      }

      final amplitude = await _recorder.getAmplitude();

print(amplitude.current);

      final length = await file.length();

    print('📦 FILE SIZE = $length');

    if (length < 1000) {
      print('❌ Recording too small');
      return;
    }
    

      final bytes = await file.readAsBytes();
      print('🎙️ Recording size: ${bytes.length} bytes');

      if (bytes.isEmpty) {
        print('❌ Recording is empty');
        return;
      }

      final filename = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await ref
          .read(messageProvider(widget.chatId).notifier)
          .sendFileMessage(bytes, filename, 'audio/mp4');
    } catch (e) {
      print('❌ Stop and send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send audio: $e')));
      }
    }
  }

  Future<void> _cancelRecording() async {
    await _recorder.cancel();
    setState(() => _isRecording = false);
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
          border: Border(top: BorderSide(color: context.glassBorder, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_isRecording)
              IconButton(
                icon: Icon(Icons.close, color: Colors.redAccent, size: 22.sp),
                onPressed: _cancelRecording,
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
                  : IconButton(
                      icon: Icon(Icons.attach_file, color: context.textTertiary, size: 22.sp),
                      onPressed: _pickAndSendFile,
                    ),

            Expanded(
              child: _isRecording
                  ? _RecordingIndicator()
                  : TextField(
                      controller: _controller,
                      onChanged: (val) => ref
                          .read(messageProvider(widget.chatId).notifier)
                          .sendTypingEvent(val.isNotEmpty),
                      style: TextStyle(color: context.textPrimary, fontSize: 15.sp),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: context.textTertiary, fontSize: 15.sp),
                        filled: true,
                        fillColor: context.glassBg,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22.r),
                          borderSide: BorderSide(color: context.glassBorder, width: 0.8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22.r),
                          borderSide: BorderSide(color: context.glassBorder, width: 0.8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22.r),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
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
                    icon: Icon(Icons.stop_circle, color: const Color(0xFF6366F1), size: 30.sp),
                    onPressed: _stopAndSend,
                  );
                }

                if (hasText) {
                  return IconButton(
                    icon: Icon(Icons.send_rounded, color: const Color(0xFF6366F1), size: 22.sp),
                    onPressed: _onSend,
                  );
                }

                return IconButton(
                  icon: Icon(Icons.mic_rounded, color: context.textTertiary, size: 22.sp),
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
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 12),
        FadeTransition(
          opacity: _opacity,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Recording...',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
