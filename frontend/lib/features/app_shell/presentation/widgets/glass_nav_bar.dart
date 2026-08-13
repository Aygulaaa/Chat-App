import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const GlassNavBar({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: context.cardBg.withValues(alpha: context.isLight ? 0.85 : 0.75),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: context.isLight 
                    ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                    : const Color(0xFF818CF8).withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.isLight
                      ? const Color(0xFF6366F1).withValues(alpha: 0.10)
                      : const Color(0xFF2D1B4E).withValues(alpha: 0.50),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chats',
                  isActive: index == 0,
                  onTap: () => onChanged(0),
                ),
                _NavItem(
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  label: 'Contacts',
                  isActive: index == 1,
                  onTap: () => onChanged(1),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  isActive: index == 2,
                  onTap: () => onChanged(2),
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
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Purple active tint adapted to light/dark themes
    final activeColor = context.isLight 
        ? const Color(0xFF6366F1) // Indigo/Violet
        : const Color(0xFFA5B4FC); // Soft Lilac Glow

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? (context.isLight
                  ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                  : const Color(0xFF818CF8).withValues(alpha: 0.25))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: isActive
              ? Border.all(
                  color: context.isLight
                      ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                      : const Color(0xFFA5B4FC).withValues(alpha: 0.45),
                  width: 1,
                )
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
    );
  }
}