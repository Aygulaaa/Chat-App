import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:my_chat_app/features/chat/presentation/widgets/message/uploading_file_tile.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

class VideoContentTile extends StatefulWidget {
  final Message message;
  final bool isUploading;
  final String Function(int) formatBytes;

  const VideoContentTile({
    super.key,
    required this.message,
    required this.isUploading,
    required this.formatBytes,
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
    if (widget.isUploading) {
      return UploadingFileTile(
        icon: Icons.videocam_outlined,
        label: widget.message.originalName ?? 'Video',
        fileSize: widget.message.fileSize,
        uploadedBytes: widget.message.uploadedBytes,
        color: Colors.purpleAccent,
      );
    }

    return GestureDetector(
      onTap: () {
        if (widget.message.fileUrl == null) return;
        context.push('/video-player', extra: {
          'url': widget.message.fileUrl!,
          'title': widget.message.originalName,
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.darkBorder,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.play_circle_filled_rounded,
                color: Colors.purpleAccent,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.originalName ?? 'Video',
                    style: const TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.message.fileSize != null)
                    Text(
                      widget.formatBytes(widget.message.fileSize!),
                      style: const TextStyle(
                        color: AppColors.darkTextTertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.darkTextTertiary,
                    ),
                  )
                : GestureDetector(
                    onTap: _saveVideoToPhotos,
                    child: const Icon(
                      Icons.download_outlined,
                      color: AppColors.darkTextTertiary,
                      size: 20,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}