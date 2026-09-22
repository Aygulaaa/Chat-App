import 'package:flutter/material.dart';

String formatBytes(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Linear upload progress: a bar, "1.2 MB / 4.0 MB · 30%", and a cancel button.
/// While the file is still waiting for its turn in the queue it says so
/// instead of showing a bar stuck at 0%.
class UploadProgress extends StatelessWidget {
  final int? uploadedBytes;
  final int? totalBytes;
  final Color color;
  final Color textColor;
  final VoidCallback? onCancel;

  const UploadProgress({
    super.key,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.color,
    required this.textColor,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = uploadedBytes ?? 0;
    final total = (totalBytes ?? 0) <= 0 ? 1 : totalBytes!;
    final progress = (uploaded / total).clamp(0.0, 1.0);
    final waiting = uploaded == 0;

    final label = waiting
        ? 'Waiting to upload…'
        : '${formatBytes(uploaded)} / ${formatBytes(totalBytes)} · '
              '${(progress * 100).round()}%';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  // Glide between the 1% steps instead of jumping
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 220),
                  builder: (_, value, _) => LinearProgressIndicator(
                    value: waiting ? null : value,
                    minHeight: 4,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.22),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        if (onCancel != null) ...[
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Cancel upload',
            child: InkResponse(
              onTap: onCancel,
              radius: 18,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                ),
                child: Icon(Icons.close_rounded, size: 16, color: textColor),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Upload progress on a photo or video, the way Telegram shows it: a ring in
/// the middle of the picture with a cancel cross inside it, and how much has
/// gone up underneath. No bar — the picture stays visible behind it.
class MediaUploadOverlay extends StatelessWidget {
  final int? uploadedBytes;
  final int? totalBytes;
  final VoidCallback? onCancel;

  const MediaUploadOverlay({
    super.key,
    required this.uploadedBytes,
    required this.totalBytes,
    this.onCancel,
  });

  static const double _ring = 54;

  @override
  Widget build(BuildContext context) {
    final uploaded = uploadedBytes ?? 0;
    final total = (totalBytes ?? 0) <= 0 ? 1 : totalBytes!;
    final progress = (uploaded / total).clamp(0.0, 1.0);
    // Nothing has left yet: spin instead of showing a ring stuck at zero.
    final waiting = uploaded == 0;

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onCancel,
              child: Container(
                width: _ring,
                height: _ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: _ring - 8,
                      height: _ring - 8,
                      child: TweenAnimationBuilder<double>(
                        // Glide between the 1% steps instead of jumping
                        tween: Tween(end: progress),
                        duration: const Duration(milliseconds: 220),
                        builder: (_, value, _) => CircularProgressIndicator(
                          value: waiting ? null : value,
                          strokeWidth: 2.5,
                          strokeCap: StrokeCap.round,
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    if (onCancel != null)
                      const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              waiting
                  ? 'Waiting…'
                  : '${formatBytes(uploaded)} / ${formatBytes(totalBytes)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
                shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
