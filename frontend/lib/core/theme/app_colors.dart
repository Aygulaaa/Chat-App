import 'package:flutter/material.dart';


abstract final class AppColors {
  static const Color primary = Color(0xFF6366F1);

 static const Color accent = Color(0xFF818CF8);

 static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Color online = Color(0xFF10B981);

 static const Color error = Colors.redAccent;

 static const Color darkBg = Color(0xFF090D16);

  static const Color darkAuthBg = Color(0xFF0B0B0E);
  static const Color darkCard = Color(0xFF1E2A3A);

  static const Color darkCardAlt = Color(0xFF16202E);
  static const Color darkSurface = Color(0xFF0B0F14);
  static const Color darkAppBar = Color(0xFF0B1120);

  static const Color darkInputFill = Color(0xFF1E1E24);
  static const Color darkModalBg = Color(0xFF0B0F14);

  static const Color darkModalSurface = Color(0xFF1A2234);
  static const Color lightBg = Color(0xFFF1F5F9);
  static const Color lightCard = Colors.white;
  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [darkBg, Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient authBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkAuthBg, Color(0xFF1A1525), Color(0xFF2D1B4E)],
    stops: [0.0, 0.5, 1.0],
  );
  static const LinearGradient lightBgGradient = LinearGradient(
    colors: [lightBg, Color(0xFFE2E8F0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: [Color(0xFF0B1120), Color(0xFF1E293B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightHeaderGradient = LinearGradient(
    colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white70;
  static const Color darkTextTertiary = Colors.white38;

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF64748B);

  static const Color darkBorder = Color(0x14FFFFFF);  
  static const Color lightBorder = Color(0x0F000000);  
}
