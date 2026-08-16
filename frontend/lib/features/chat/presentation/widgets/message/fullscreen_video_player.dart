import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class FullscreenVideoPlayer extends StatefulWidget {
  final String url;
  final String? title;

  const FullscreenVideoPlayer({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.play();
        }
      });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _downloadVideo() async {
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(Uri.parse(widget.url));
      final dir = await getApplicationDocumentsDirectory();
      final filename = widget.title ?? 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File('${dir.path}/$filename');
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(color: AppColors.primary),
            ),

            // Top bar
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            widget.title ?? 'Video',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: _downloadVideo,
                              ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom controls
            if (_showControls && _isInitialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                _formatDuration(_controller.value.position),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12,
                                    ),
                                    activeTrackColor: AppColors.primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: AppColors.primary,
                                  ),
                                  child: Slider(
                                    value: _controller.value.position.inMilliseconds
                                        .toDouble()
                                        .clamp(
                                          0,
                                          _controller.value.duration.inMilliseconds
                                              .toDouble(),
                                        ),
                                    max: _controller.value.duration.inMilliseconds
                                        .toDouble(),
                                    onChanged: (value) {
                                      _controller.seekTo(
                                        Duration(milliseconds: value.toInt()),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(_controller.value.duration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Play/pause button
                        IconButton(
                          iconSize: 48,
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
