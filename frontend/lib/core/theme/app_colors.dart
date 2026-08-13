import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF6366F1);
  static const Color accent = Color(0xFF818CF8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color online = Color(0xFF10B981);
  static const Color error = Colors.redAccent;

  // Purple-Oriented Dark Theme Colors
  static const Color darkBg = Color(0xFF0B0914); // Deep void purple
  static const Color darkAuthBg = Color(0xFF0B0B0E);
  static const Color darkCard = Color(0xFF171326); // Deep violet surface
  static const Color darkCardAlt = Color(
    0xFF1F1A33,
  ); // Slightly lighter purple card
  static const Color darkSurface = Color(0xFF0B0914);
  static const Color darkAppBar = Color(0xFF120E21);

  static const Color darkInputFill = Color(0xFF19142B);
  static const Color darkModalBg = Color(0xFF0B0914);
  static const Color darkModalSurface = Color(0xFF1C1733);

  // Glassmorphic & Whitish Sky Blue Light Theme Colors
  static const Color lightBg = Color(0xFFF0F6FF); // Soft icy sky blue tint
  static const Color lightCard = Color(0xCCFFFFFF); // 80% opacity translucent frosted white
  static const Color lightCardAlt = Color(0xB8F0F7FF); // Translucent sky-tinted white
  static const Color lightSurface = Color(0xE6FAFCFF);
  static const Color lightAppBar = Color(0xD9EBF3FE);

  static const Color lightInputFill = Color(0x99E2EEFF); // Soft glassmorphic sky input
  static const Color lightModalBg = Color(0xFFF4F8FE);
  static const Color lightModalSurface = Color(0xE6FFFFFF);

  // Background & Header Gradients
  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [darkBg, Color(0xFF1A132C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient authBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkAuthBg, Color(0xFF1A1525), Color(0xFF2D1B4E)],
    stops: [0.0, 0.5, 1.0],
  );

  // Crisp Glassmorphic Sky Blue Light Background
  static const LinearGradient lightBgGradient = LinearGradient(
    colors: [
      Color(0xFFEBF3FE), // Icy sky top
      Color(0xFFF8FAFC), // Pure soft white bottom
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: [Color(0xFF120E21), Color(0xFF221A3B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Light Sky Glass Header
  static const LinearGradient lightHeaderGradient = LinearGradient(
    colors: [
      Color(0xE6E2EEFF),
      Color(0xCCF0F7FF),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Text Colors
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary =
      Color.fromARGB(255, 90, 88, 90); // Slightly warmer purple-tinted grey

  static const Color lightTextPrimary = Color(0xFF0F172A); // Deep slate for high contrast
  static const Color lightTextSecondary = Color(0xFF334155); // Cool slate secondary
  static const Color lightTextTertiary = Color(0xFF64748B); // Muted sky slate

  // Borders
  static const Color darkBorder = Color(
    0x2B818CF8,
  ); // Subtle accent tint border
  
  // Glassmorphic border with subtle icy glow
  static const Color lightBorder = Color(0x3B3B82F6); 
  static const Color lightGlassBorder = Color(0x66FFFFFF); // Bright white edge for glass reflection
}