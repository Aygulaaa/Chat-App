import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/inlineAudioPlayer.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/fullscreen_video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageContent extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageContent({super.key, required this.message, required this.isMe});

  bool get _isUploading => message.status == MessageStatus.uploading;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    switch (message.fileType) {
      case MessageType.text:
        return Text(
          message.text ?? '',
          style: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontSize: 15,
            height: 1.45,
          ),
        );

      case MessageType.image:
        return _buildImageContent(context);

      case MessageType.video:
        return _VideoContentTile(
          message: message,
          isUploading: _isUploading,
          formatBytes: _formatBytes,
        );

      case MessageType.audio:
        if (_isUploading) {
          return _UploadingFileTile(
            icon: Icons.audiotrack_rounded,
            label: message.originalName ?? 'Audio',
            fileSize: message.fileSize,
            uploadedBytes: message.uploadedBytes,
            color: const Color(0xFF4CC9F0),
          );
        }
        return InlineAudioPlayer(
          url: message.fileUrl!,
          color: isMe ? AppColors.darkTextPrimary : const Color(0xFF4CC9F0),
        );

      case MessageType.pdf:
        if (_isUploading) {
          return _UploadingFileTile(
            icon: Icons.picture_as_pdf_outlined,
            label: message.originalName ?? 'Document.pdf',
            fileSize: message.fileSize,
            uploadedBytes: message.uploadedBytes,
            color: AppColors.error,
          );
        }
        return _FileTile(
          icon: Icons.picture_as_pdf_outlined,
          label: message.originalName ?? 'Document.pdf',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: AppColors.error,
        );

      case MessageType.archive:
        if (_isUploading) {
          return _UploadingFileTile(
            icon: Icons.folder_zip_outlined,
            label: message.originalName ?? 'Archive',
            fileSize: message.fileSize,
            uploadedBytes: message.uploadedBytes,
            color: Colors.orangeAccent,
          );
        }
        return _FileTile(
          icon: Icons.folder_zip_outlined,
          label: message.originalName ?? 'Archive',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: Colors.orangeAccent,
        );

      case MessageType.file:
        if (_isUploading) {
          return _UploadingFileTile(
            icon: Icons.insert_drive_file_outlined,
            label: message.originalName ?? 'File',
            fileSize: message.fileSize,
            uploadedBytes: message.uploadedBytes,
            color: AppColors.accent,
          );
        }
        return _FileTile(
          icon: Icons.insert_drive_file_outlined,
          label: message.originalName ?? 'File',
          fileSize: message.fileSize,
          url: message.fileUrl,
          color: AppColors.accent,
        );
    }
  }

  Widget _buildImageContent(BuildContext context) {
    Widget imageWidget;

    if (_isUploading && message.localPath != null) {
      imageWidget = Image.file(
        File(message.localPath!),
        width: 200,
        fit: BoxFit.cover,
      );
    } else if (_isUploading) {
      imageWidget = Container(
        width: 200,
        height: 150,
        color: AppColors.darkCard,
        child: const Center(
          child: Icon(Icons.image, color: AppColors.darkTextTertiary, size: 40),
        ),
      );
    } else {
      imageWidget = Image.network(
        message.fileUrl!,
        width: 200,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
      );
    }

    return GestureDetector(
      onTap: _isUploading
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _FullscreenImageViewer(
                    url: message.fileUrl!,
                    title: message.originalName,
                  ),
                ),
              );
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            imageWidget,
            if (_isUploading) _buildUploadOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOverlay() {
    final uploaded = message.uploadedBytes ?? 0;
    final total = message.fileSize ?? 1;
    final progress = (uploaded / total).clamp(0.0, 1.0);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 3,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatBytes(uploaded)} / ${_formatBytes(total)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Video Tile Widget with Save to Photos
// ──────────────────────────────────────────────
class _VideoContentTile extends StatefulWidget {
  final Message message;
  final bool isUploading;
  final String Function(int) formatBytes;

  const _VideoContentTile({
    required this.message,
    required this.isUploading,
    required this.formatBytes,
  });

  @override
  State<_VideoContentTile> createState() => _VideoContentTileState();
}

class _VideoContentTileState extends State<_VideoContentTile> {
  bool _isSaving = false;

  Future<void> _saveVideoToPhotos() async {
    final url = widget.message.fileUrl;
    if (url == null) return;

    setState(() => _isSaving = true);
    try {
      final response = await http.get(Uri.parse(url));
      final tempDir = await getTemporaryDirectory();
      final ext = url.split('.').last.split('?').first;
      final tempFile = File('${tempDir.path}/temp_vid_${DateTime.now().millisecondsSinceEpoch}.$ext');
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
      return _UploadingFileTile(
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullscreenVideoPlayer(
              url: widget.message.fileUrl!,
              title: widget.message.originalName,
            ),
          ),
        );
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

// ──────────────────────────────────────────────
// Full-screen image viewer with Save to Photos
// ──────────────────────────────────────────────
class _FullscreenImageViewer extends StatefulWidget {
  final String url;
  final String? title;

  const _FullscreenImageViewer({required this.url, this.title});

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  bool _isDownloading = false;

  Future<void> _downloadImageToPhotos() async {
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(Uri.parse(widget.url));
      await Gal.putImageBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to Photos'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title ?? 'Image',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          _isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: _downloadImageToPhotos,
                ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(widget.url),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Upload progress file tile
// ──────────────────────────────────────────────
class _UploadingFileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? fileSize;
  final int? uploadedBytes;
  final Color color;

  const _UploadingFileTile({
    required this.icon,
    required this.label,
    this.fileSize,
    this.uploadedBytes,
    required this.color,
  });

  String _formatBytes(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final uploaded = uploadedBytes ?? 0;
    final total = fileSize ?? 1;
    final progress = (uploaded / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkBorder,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2.5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
                Icon(icon, color: color, size: 14),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_formatBytes(uploaded)} / ${_formatBytes(fileSize)}',
                  style: const TextStyle(
                    color: AppColors.darkTextTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Downloadable file tile
// ──────────────────────────────────────────────
class _FileTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final int? fileSize;
  final String? url;
  final Color color;

  const _FileTile({
    required this.icon,
    required this.label,
    required this.fileSize,
    required this.url,
    required this.color,
  });

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _isDownloading = false;

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Future<void> _downloadFile() async {
    if (widget.url == null) return;
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(Uri.parse(widget.url!));
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.label}');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path}'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (widget.url == null) return;
        final uri = Uri.parse(widget.url!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
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
            Icon(widget.icon, color: widget.color, size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.fileSize != null)
                    Text(
                      _formatSize(widget.fileSize),
                      style: const TextStyle(
                        color: AppColors.darkTextTertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.darkTextTertiary,
                    ),
                  )
                : GestureDetector(
                    onTap: _downloadFile,
                    child: const Icon(
                      Icons.download_outlined,
                      color: AppColors.darkTextTertiary,
                      size: 18,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}