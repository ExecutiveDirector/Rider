// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF0066FF);
  static const Color primaryDark = Color(0xFF0047CC);
  static const Color primaryLight = Color(0xFFE8F0FF);
  static const Color accent = Color(0xFF00C48C);

  // Status
  static const Color success = Color(0xFF00C48C);
  static const Color warning = Color(0xFFFFA800);
  static const Color error = Color(0xFFFF4D4F);
  static const Color info = Color(0xFF1890FF);

  // Order status colors
  static const Color pending = Color(0xFFFFA800);
  static const Color accepted = Color(0xFF0066FF);
  static const Color inTransit = Color(0xFF722ED1);
  static const Color delivered = Color(0xFF00C48C);
  static const Color cancelled = Color(0xFFFF4D4F);

  // Neutral
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFF0F0F0);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);

  // Online/Offline
  static const Color online = Color(0xFF00C48C);
  static const Color offline = Color(0xFF9CA3AF);
}
