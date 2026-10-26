import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

const List<String> kStickers = ['😂', '❤️', '👍', '😮', '😢', '🔥', '🎉', '👏', '😍'];

class StickerStrip extends StatelessWidget {
  final bool isMe;
  final void Function(String emoji) onTap;

  /// The emoji already on the message from me — drawn with a filled circle
  /// behind it, so tapping it again clearly means "take it off".
  final String? selected;

  const StickerStrip({
    super.key,
    required this.isMe,
    required this.onTap,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.82,
      ),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: context.glassBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isLight ? 0.08 : 0.25),
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
              isSelected: kStickers[index] == selected,
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
  final bool isSelected;

  const _StickerButton({
    required this.emoji,
    required this.onTap,
    this.isSelected = false,
  });

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

  /// One tap = one reaction. The callback toggles on the server, so a second
  /// delivery would undo the first; the pop animation must not gate it.
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_tapped) return;
        _tapped = true;
        _ctrl.forward().then((_) => _ctrl.reverse());
        // Fired immediately: the 80ms delay this used to wait out only
        // widened the window for a second tap to land.
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Center(
            child: Container(
              padding: EdgeInsets.all(5.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected
                    ? context.primaryColor.withValues(alpha: 0.22)
                    : Colors.transparent,
              ),
              child: Text(
                widget.emoji,
                style: TextStyle(fontSize: 22.sp),
              ),
            ),
          ),
        ),
      ),
    );
  }
}