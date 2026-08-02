// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

/// Brand palette — emerald green, matching the rest of the AquaGas suite
/// (customer app + admin panel both use #10B981 / #065F46).
///
/// Order-status colors are deliberately NOT all green — a rider scanning a
/// list needs to tell "awaiting pickup" from "en route" from "delivered" at
/// a glance, so those keep distinct hues. Green is reserved for brand chrome
/// (headers, buttons, nav, focus states) and for the "delivered" / "online"
/// states — the two moments that should feel like a payoff.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF10B981); // Emerald 500
  static const Color primaryDark = Color(0xFF065F46); // Emerald 800
  static const Color primaryLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color primaryDeep = Color(0xFF042F23); // near-black green
  static const Color accentMint = Color(0xFF34D399); // Emerald 400
  static const Color accent = Color(0xFF0D9488); // Teal 600 — secondary accent

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);
  static const Color violet = Color(0xFF8B5CF6);

  // ── Order status colors ───────────────────────────────────────────────
  // pending (amber) -> accepted (violet, at vendor) -> inTransit (sky, moving)
  // -> delivered (brand green, the payoff) -> cancelled (red)
  static const Color pending = Color(0xFFF59E0B);
  static const Color accepted = Color(0xFF8B5CF6);
  static const Color inTransit = Color(0xFF0EA5E9);
  static const Color delivered = Color(0xFF10B981);
  static const Color cancelled = Color(0xFFEF4444);

  // ── Neutrals (Tailwind "slate", pairs cleanly with emerald) ───────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color divider = Color(0xFFE6ECE9);
  static const Color background = Color(0xFFF5F8F7);
  static const Color surface = Color(0xFFFFFFFF);

  // ── Online / offline — tied straight to brand: online = earning = green ─
  static const Color online = Color(0xFF10B981);
  static const Color offline = Color(0xFF94A3B8);

  // ── Dark theme neutrals ────────────────────────────────────────────────
  static const Color surfaceDark = Color(0xFF132420);
  static const Color borderDark = Color(0xFF1F3B33);
  static const Color scaffoldDark = Color(0xFF0A1712);
  static const Color textPrimaryDark = Color(0xFFECFDF5);
  static const Color textSecondaryDark = Color(0xFFA7C4B8);

  // ── Gradients ──────────────────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), primaryDark],
  );

  static const LinearGradient brightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentMint, Color(0xFF059669)],
  );

  static const LinearGradient deepGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDeep, Color(0xFF07281F)],
  );

  static const LinearGradient earnGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accent, Color(0xFF059669)],
  );

  /// A soft two-stop gradient built from any status color, for badges/bars
  /// that want a little depth instead of a flat fill.
  static LinearGradient statusGradient(Color color) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, Color.lerp(color, Colors.black, 0.16)!],
      );
}
