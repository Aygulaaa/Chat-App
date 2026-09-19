import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

class VideoContentTile extends StatefulWidget {
  final Message message;
  final bool isUploading;
  final String Function(int) formatBytes;
  final String formattedTime;
  final bool isMe;
  final Widget? statusIcon;

  const VideoContentTile({
    super.key,
    required this.message,
    required this.isUploading,
    required this.formatBytes,
    required this.formattedTime,
    required this.isMe,
    this.statusIcon,
  });

  @override
  State<VideoContentTile> createState() => _VideoContentTileState();
}

class _VideoContentTileState extends State<VideoContentTile> {
  bool _isSaving = false;

  Future<void> _saveVideoToPhotos() async {
    final url = widget.message.fileUrl;
    if (url == null) return;

    setState(() => _isSaving = true);
    try {
      final response = await http.get(Uri.parse(url));
      final tempDir = await getTemporaryDirectory();
      final ext = url.split('.').last.split('?').first;
      final tempFile = File(
          '${tempDir.path}/temp_vid_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await tempFile.writeAsBytes(response.bodyBytes);

      await Gal.putVideo(tempFile.path);
      await tempFile.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved to Photos'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save video: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.message.fileUrl == null || widget.isUploading) return;
        context.push('/video-player', extra: {
          'url': widget.message.fileUrl!,
          'title': widget.message.originalName,
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 250,
          height: 170,
          color: const Color(0xFF1E2732), // Dark Telegram video placeholder background
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Dark Gradient overlay for contrast
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),

              // 2. Centered Frosted Play / Cancel Button
              Center(
                child: widget.isUploading
                    ? _buildUploadingIndicator()
                    : Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
              ),

              // 3. Top-Right Save / Download Button
              if (!widget.isUploading)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _saveVideoToPhotos,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                    ),
                  ),
                ),

              // 4. Bottom-Left File Size Badge
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      if (widget.message.fileSize != null)
                        Text(
                          widget.formatBytes(widget.message.fileSize!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 5. Telegram-Style Bottom-Right Timestamp & Checkmarks
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.formattedTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (widget.isMe && widget.statusIcon != null) ...[
                        const SizedBox(width: 3),
                        widget.statusIcon!,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadingIndicator() {
    final uploaded = widget.message.uploadedBytes ?? 0;
    final total = widget.message.fileSize ?? 1;
    final progress = (uploaded / total).clamp(0.0, 1.0);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            strokeWidth: 3,
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
          const Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
    );
  }
}