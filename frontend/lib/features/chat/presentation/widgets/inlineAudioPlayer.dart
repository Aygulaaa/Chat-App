import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class InlineAudioPlayer extends StatefulWidget {
  final String url;
  final Color color;

  const InlineAudioPlayer({super.key, required this.url, required this.color});

  @override
  State<InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<InlineAudioPlayer> {
  late final AudioPlayer _player;

  bool _isPlaying = false;
  bool _isLoading = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();

    _initAudio();

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPlaying = state == PlayerState.playing;

        if (state == PlayerState.completed) {
          _position = Duration.zero;
        }
      });
    });

    _player.onDurationChanged.listen((d) {
      if (!mounted) return;

      setState(() {
        _duration = d;
      });
    });

    _player.onPositionChanged.listen((p) {
      if (!mounted) return;

      setState(() {
        _position = p;
      });
    });
  }

  Future<void> _initAudio() async {
  try {
    if (mounted) setState(() => _isLoading = true);
    await _player.setSource(UrlSource(widget.url));
    await _player.resume();
    await _player.pause();
    await _player.seek(Duration.zero);
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
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play(UrlSource(widget.url));
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
    final maxMs = _duration.inMilliseconds.toDouble();

    final posMs = _position.inMilliseconds.toDouble().clamp(
      0.0,
      maxMs > 0 ? maxMs : 1.0,
    );

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
                : Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: widget.color,
                    size: 40,
                  ),
          ),

          Expanded(
            child: Column(
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
                    inactiveColor: Colors.white.withOpacity(0.1),
                    value: posMs,
                    max: maxMs > 0 ? maxMs : 1,
                    onChanged: (v) async {
                      await _player.seek(Duration(milliseconds: v.toInt()));
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if(_isPlaying)
                        Text(
                          _fmt(_position),
                          style:  TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 9,
                          ),
                        ),
                      Text(
                        _fmt(_duration),
                        style:  TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 9,
                        ),
                      ),
                    ],
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
