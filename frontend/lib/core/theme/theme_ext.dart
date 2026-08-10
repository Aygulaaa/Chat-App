import 'package:flutter/material.dart';

extension ThemeExt on BuildContext {
  // Check if current theme is light
  bool get isLight => Theme.of(this).brightness == Brightness.light;

  // Scaffold background color (Dynamic glassmorphism backdrop)
  Color get appBg => isLight ? const Color(0xFFF1F5F9) : const Color(0xFF090D16);

  // Standard card background color
  Color get cardBg => isLight ? Colors.white : const Color(0xFF1E2A3A);

  // Glassmorphic panel background
  Color get glassBg => isLight 
      ? Colors.white.withOpacity(0.7) 
      : Colors.white.withOpacity(0.05);

  // Glassmorphic panel border color
  Color get glassBorder => isLight 
      ? Colors.black.withOpacity(0.06) 
      : Colors.white.withOpacity(0.08);

  // Text color - primary
  Color get textPrimary => isLight ? const Color(0xFF0F172A) : Colors.white;

  // Text color - secondary
  Color get textSecondary => isLight ? const Color(0xFF475569) : Colors.white70;

  // Text color - tertiary / captions
  Color get textTertiary => isLight ? const Color(0xFF64748B) : Colors.white38;

  // Primary colors matching Teleflow branding
  Color get primaryColor => const Color(0xFF6366F1);
  Color get accentColor => const Color(0xFF818CF8);
  
  // Dynamic gradient for backgrounds / page headers
  LinearGradient get appBgGradient => isLight
      ? const LinearGradient(
          colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      : const LinearGradient(
          colors: [Color(0xFF090D16), Color(0xFF111827)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );

  // Dynamic gradient for message bubbles / items
  LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
