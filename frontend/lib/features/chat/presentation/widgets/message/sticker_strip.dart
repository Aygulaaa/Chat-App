import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

const List<String> kStickers = ['😂', '❤️', '👍', '😮', '😢', '🔥', '🎉', '👏', '😍'];

class StickerStrip extends StatelessWidget {
  final bool isMe;
  final void Function(String emoji) onTap;

  const StickerStrip({
    super.key,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: AppColors.darkBorder.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          itemCount: kStickers.length,
          itemBuilder: (context, index) {
            return _StickerButton(
              emoji: kStickers[index],
              onTap: () => onTap(kStickers[index]),
            );
          },
        ),
      ),
    );
  }
}

class _StickerButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _StickerButton({required this.emoji, required this.onTap});

  @override
  State<_StickerButton> createState() => _StickerButtonState();
}

class _StickerButtonState extends State<_StickerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _ctrl.forward().then((_) => _ctrl.reverse());
        Future.delayed(const Duration(milliseconds: 80), widget.onTap);
      },
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Center(
            child: Text(
              widget.emoji,
              style: TextStyle(fontSize: 22.sp),
            ),
          ),
        ),
      ),
    );
  }
}