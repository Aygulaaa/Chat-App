import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

/// Drag a message sideways to reply to it (the Telegram / WhatsApp gesture).
///
/// The bubble follows the finger with rubber-band resistance, a reply icon
/// fades and scales in behind it, a single haptic tick fires at the point of
/// no return, and the bubble springs back on release.
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;

  /// Own messages sit on the right and are pulled LEFT; others are pulled right
  /// — so the bubble always moves toward the empty side of the screen.
  final bool swipeLeft;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.swipeLeft = false,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _trigger = 56;
  static const double _maxDrag = 84;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<double>? _settleAnimation;

  double _offset = 0; // always >= 0; direction is applied when painting
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      final animation = _settleAnimation;
      if (animation != null) setState(() => _offset = animation.value);
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    final delta = widget.swipeLeft ? -details.delta.dx : details.delta.dx;
    // Rubber band: the further it's pulled, the less it moves
    final resistance = 1 - (_offset / _maxDrag).clamp(0.0, 1.0) * 0.75;
    final next = (_offset + delta * resistance).clamp(0.0, _maxDrag);

    if (!_armed && next >= _trigger) {
      _armed = true;
      HapticFeedback.mediumImpact();
    } else if (_armed && next < _trigger) {
      _armed = false;
    }
    setState(() => _offset = next);
  }

  void _onEnd([DragEndDetails? _]) {
    if (_armed) widget.onReply?.call();
    _armed = false;

    _settleAnimation = Tween<double>(begin: _offset, end: 0).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOutBack),
    );
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) return widget.child;

    final progress = (_offset / _trigger).clamp(0.0, 1.0);
    final direction = widget.swipeLeft ? -1.0 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _settle.stop(),
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _onEnd,
      child: Stack(
        alignment: widget.swipeLeft
            ? Alignment.centerRight
            : Alignment.centerLeft,
        children: [
          if (_offset > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.5 + progress * 0.5,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(
                        alpha: _armed ? 0.28 : 0.14,
                      ),
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_offset * direction, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
