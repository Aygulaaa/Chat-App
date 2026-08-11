import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class InlineAudioPlayer extends StatefulWidget {
  final String url;
  final Color color;

  const InlineAudioPlayer({super.key, required this.url, required this.color});

  @override
  State<InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<InlineAudioPlayer> {
  late final AudioPlayer _player;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      await _player.setUrl(widget.url);
    } catch (e) {
      print('Audio init error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        // If it reached the end, reset position before playing again
        if (_player.position >= (_player.duration ?? Duration.zero)) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
    } catch (e) {
      print('Play error: $e');
    }
  }

  String _fmt(Duration d) {
    if (d == Duration.zero) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: _isLoading
                ? SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.color,
                    ),
                  )
                : StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final isPlaying = playerState?.playing ?? false;
                      final processingState = playerState?.processingState;

                      if (processingState == ProcessingState.loading ||
                          processingState == ProcessingState.buffering) {
                        return SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.color,
                          ),
                        );
                      }

                      return Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: widget.color,
                        size: 40,
                      );
                    },
                  ),
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                return StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, durationSnapshot) {
                    final duration = durationSnapshot.data ?? Duration.zero;

                    final maxMs = duration.inMilliseconds.toDouble();
                    final posMs = position.inMilliseconds.toDouble().clamp(
                          0.0,
                          maxMs > 0 ? maxMs : 1.0,
                        );

                    final isPlaying = _player.playing;

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            activeColor: widget.color,
                            inactiveColor: AppColors.darkBorder,
                            value: posMs,
                            max: maxMs > 0 ? maxMs : 1.0,
                            onChanged: (v) async {
                              await _player.seek(
                                Duration(milliseconds: v.toInt()),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (isPlaying)
                                Text(
                                  _fmt(position),
                                  style: const TextStyle(
                                    color: AppColors.darkTextTertiary,
                                    fontSize: 9,
                                  ),
                                ),
                              Text(
                                _fmt(duration),
                                style: const TextStyle(
                                  color: AppColors.darkTextTertiary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}