import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

/// Production-ready Theme and Color extension on [BuildContext].
/// Provides safe, high-performance, and reactive theme token access.
extension ThemeExt on BuildContext {
  /// Theme brightness helper with safety context check.
  bool get isLight {
    return Theme.of(this).brightness == Brightness.light;
  }

  /// Active color scheme token source (resolves [LightColors] or [DarkColors]).
  AppColorScheme get colors => AppColors.of(this);

  // ==========================================
  // Background & Surface Tokens
  // ==========================================
  Color get appBg => colors.bg;
  Color get cardBg => colors.card;
  Color get cardAltBg => colors.cardAlt;
  Color get surfaceBg => colors.surface;
  Color get appBarBg => colors.appBar;
  Color get inputFill => colors.inputFill;
  Color get modalBg => colors.modalBg;
  Color get modalSurface => colors.modalSurface;

  // ==========================================
  // Glassmorphic & Border Tokens
  // ==========================================
  Color get glassBg => colors.surface;
  Color get glassBorder => colors.glassBorder;
  Color get border => colors.border;

  // ==========================================
  // Typography Tokens
  // ==========================================
  Color get textPrimary => colors.textPrimary;
  Color get textSecondary => colors.textSecondary;
  Color get textTertiary => colors.textTertiary;

  // ==========================================
  // Brand Identity Tokens
  // ==========================================
  Color get primaryColor => AppColors.primary;
  Color get accentColor => AppColors.accent;
  Color get onlineStatus => AppColors.online;
  Color get errorColor => AppColors.error;

  // ==========================================
  // Gradient Tokens
  // ==========================================
  LinearGradient get appBgGradient => colors.bgGradient;
  LinearGradient get authBgGradient => colors.authGradient;
  LinearGradient get headerGradient => colors.headerGradient;
  LinearGradient get primaryGradient => AppColors.primaryGradient;
}


