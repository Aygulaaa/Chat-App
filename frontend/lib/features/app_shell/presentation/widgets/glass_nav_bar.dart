import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class GlassNavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const GlassNavBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar> {
  bool _isDragging = false;
  double _dragAlignmentX = 0.0;

  // Exact alignments for 3 equal-width columns (1/3 width each)
  final List<double> _alignments = [-1.0, 0.0, 1.0];

  double _getAlignmentForIndex(int index) {
    if (index >= 0 && index < _alignments.length) {
      return _alignments[index];
    }
    return 0.0;
  }

  int _getNearestIndex(double alignmentX) {
    if (alignmentX < -0.33) return 0;
    if (alignmentX > 0.33) return 2;
    return 1;
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    // Convert local drag coordinate to alignment space [-1.0, 1.0]
    final rawX = (details.localPosition.dx / width) * 2.0 - 1.0;
    final clampedX = rawX.clamp(-1.0, 1.0);
    final nearestIndex = _getNearestIndex(clampedX);

    setState(() {
      _isDragging = true;
      _dragAlignmentX = clampedX;
    });

    // Live update selection so text & icon expansion sync with the moving pill
    if (nearestIndex != widget.index) {
      widget.onChanged(nearestIndex);
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final targetIndex = _getNearestIndex(_dragAlignmentX);
    setState(() {
      _isDragging = false;
    });
    widget.onChanged(targetIndex);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final targetAlignmentX = _isDragging
        ? _dragAlignmentX
        : _getAlignmentForIndex(widget.index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onHorizontalDragUpdate: (details) =>
                    _handleDragUpdate(details, constraints.maxWidth),
                onHorizontalDragEnd: _handleDragEnd,
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: colors.glassBorder,
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Glass Pill Backdrop
                      AnimatedAlign(
                        duration: _isDragging
                            ? Duration.zero
                            : const Duration(milliseconds: 280),
                        curve: Curves.fastOutSlowIn,
                        alignment: Alignment(targetAlignmentX, 0.0),
                        child: FractionallySizedBox(
                          widthFactor: 1 / 3,
                          heightFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(35),
                              border: Border.all(
                                color: colors.border,
                                width: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Interactive Tab Elements
                      Row(
                        children: [
                          _NavItem(
                            itemIndex: 0,
                            icon: Icons.chat_bubble_outline_rounded,
                            activeIcon: Icons.chat_bubble_rounded,
                            label: 'Chats',
                            isActive: widget.index == 0,
                            onTap: widget.onChanged,
                            colors: colors,
                          ),
                          _NavItem(
                            itemIndex: 1,
                            icon: Icons.people_outline_rounded,
                            activeIcon: Icons.people_rounded,
                            label: 'Contacts',
                            isActive: widget.index == 1,
                            onTap: widget.onChanged,
                            colors: colors,
                          ),
                          _NavItem(
                            itemIndex: 2,
                            icon: Icons.person_outline_rounded,
                            activeIcon: Icons.person_rounded,
                            label: 'Profile',
                            isActive: widget.index == 2,
                            onTap: widget.onChanged,
                            colors: colors,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int itemIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final ValueChanged<int> onTap;
  final AppColorScheme colors;

  const _NavItem({
    required this.itemIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final activeTextColor = colors.textPrimary;
    final inactiveIconColor = colors.textTertiary;

    return Expanded(
      child: Semantics(
        selected: isActive,
        label: '$label tab',
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(itemIndex),
          child: Container(
            height: double.infinity,
            alignment: Alignment.center, // Strict center alignment inside column slot
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey<bool>(isActive),
                    color: isActive ? activeTextColor : inactiveIconColor,
                    size: 20,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.fastOutSlowIn,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: activeTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}