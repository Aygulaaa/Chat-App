import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

extension ThemeExt on BuildContext {
  // Check if current theme is light
  bool get isLight => Theme.of(this).brightness == Brightness.light;

  // Scaffold background color (Dynamic glassmorphism backdrop)
  Color get appBg => isLight ? AppColors.lightBg : AppColors.darkBg;

  // Standard card background color
  Color get cardBg => isLight ? AppColors.lightCard : AppColors.darkCard;

  // Glassmorphic panel background
  Color get glassBg => isLight
      ? Colors.white.withOpacity(0.7)
      : Colors.white.withOpacity(0.05);

  // Glassmorphic panel border color
  Color get glassBorder => isLight ? AppColors.lightBorder : AppColors.darkBorder;

  // Text color - primary
  Color get textPrimary => isLight ? AppColors.lightTextPrimary : AppColors.darkTextPrimary;

  // Text color - secondary
  Color get textSecondary => isLight ? AppColors.lightTextSecondary : AppColors.darkTextSecondary;

  // Text color - tertiary / captions
  Color get textTertiary => isLight ? AppColors.lightTextTertiary : AppColors.darkTextTertiary;

  // Primary brand color
  Color get primaryColor => AppColors.primary;

  // Accent brand color
  Color get accentColor => AppColors.accent;

  // Dynamic gradient for backgrounds / page headers
  LinearGradient get appBgGradient =>
      isLight ? AppColors.lightBgGradient : AppColors.darkBgGradient;

  // Dynamic gradient for message bubbles / items
  LinearGradient get primaryGradient => AppColors.primaryGradient;
}

