import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class TypingIndicator extends StatefulWidget {
  final String? avatarUrl;

  const TypingIndicator({
    super.key,
    this.avatarUrl,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.avatarUrl != null) ...[
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.darkCard,
                backgroundImage: CachedNetworkImageProvider(widget.avatarUrl!),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => _Dot(index: i, controller: _controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int index;
  final AnimationController controller;

  const _Dot({required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    final delay = index * 0.2;

    final animation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -5.0),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -5.0, end: 0.0),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Transform.translate( 
        offset: Offset(0, animation.value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.darkTextTertiary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}