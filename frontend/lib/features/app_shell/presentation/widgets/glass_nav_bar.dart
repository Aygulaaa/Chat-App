import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const GlassNavBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    // Cache theme-dependent colors outside of child builders
    final bgAlpha = isLight ? 0.85 : 0.75;
    final borderAlpha = isLight ? 0.15 : 0.25;
    final shadowAlpha = isLight ? 0.10 : 0.50;

    final borderColor = isLight ? const Color(0xFF6366F1) : const Color(0xFF818CF8);
    final shadowColor = isLight ? const Color(0xFF6366F1) : const Color(0xFF2D1B4E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: context.cardBg.withValues(alpha: bgAlpha),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: borderColor.withValues(alpha: borderAlpha),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withValues(alpha: shadowAlpha),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  itemIndex: 0,
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chats',
                  isActive: index == 0,
                  onTap: onChanged,
                ),
                _NavItem(
                  itemIndex: 1,
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  label: 'Contacts',
                  isActive: index == 1,
                  onTap: onChanged,
                ),
                _NavItem(
                  itemIndex: 2,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  isActive: index == 2,
                  onTap: onChanged,
                ),
              ],
            ),
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

  const _NavItem({
    required this.itemIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    final activeColor = isLight 
        ? const Color(0xFF6366F1) 
        : const Color(0xFFA5B4FC);

    final bgActiveColor = isLight
        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
        : const Color(0xFF818CF8).withValues(alpha: 0.25);

    final borderActiveColor = isLight
        ? const Color(0xFF6366F1).withValues(alpha: 0.35)
        : const Color(0xFFA5B4FC).withValues(alpha: 0.45);

    // Semantics node adds full accessibility & screen reader support
    return Semantics(
      selected: isActive,
      label: '$label tab',
      button: true,
      child: InkWell(
        onTap: () => onTap(itemIndex),
        borderRadius: BorderRadius.circular(30),
        highlightColor: Colors.transparent,
        splashColor: activeColor.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 18 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isActive ? bgActiveColor : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: isActive
                ? Border.all(color: borderActiveColor, width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? activeColor : context.textTertiary,
                size: 22,
              ),
              if (isActive) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: activeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}