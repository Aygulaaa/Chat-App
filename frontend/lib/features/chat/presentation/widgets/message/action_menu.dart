import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class ActionMenu extends StatelessWidget {
  final bool isMe;
  final bool hasText;
  final bool showingInfo;
  final VoidCallback onCopy;
  final VoidCallback onInfo;
  final VoidCallback onDelete;

  const ActionMenu({
    super.key,
    required this.isMe,
    required this.hasText,
    required this.showingInfo,
    required this.onCopy,
    required this.onInfo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final List<_TileSpec> tiles = [
      if (hasText)
        _TileSpec(
          icon: Icons.content_copy_rounded,
          label: 'Copy',
          onTap: onCopy,
        ),
      _TileSpec(
        icon: showingInfo ? Icons.info_rounded : Icons.info_outline_rounded,
        label: 'Message Info',
        onTap: onInfo,
        iconColor: AppColors.accent,
      ),
      if (isMe)
        _TileSpec(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          onTap: onDelete,
          iconColor: AppColors.error,
          labelColor: AppColors.error,
        ),
    ];

    return Container(
      width: 200.w,
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.darkBorder.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1.h,
                  thickness: 0.6.h,
                  color: AppColors.darkBorder.withValues(alpha: 0.5),
                ),
              _ActionTile(spec: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TileSpec {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color? labelColor;

  const _TileSpec({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = AppColors.darkTextSecondary,
    this.labelColor,
  });
}

class _ActionTile extends StatefulWidget {
  final _TileSpec spec;

  const _ActionTile({required this.spec});

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.spec.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        color: _pressed
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        child: Row(
          children: [
            Icon(
              widget.spec.icon,
              size: 18.sp,
              color: widget.spec.iconColor,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                widget.spec.label,
                style: TextStyle(
                  color: widget.spec.labelColor ?? AppColors.darkTextPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}