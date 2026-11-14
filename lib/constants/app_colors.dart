import 'package:flutter/material.dart';

/// Ndichan Brand Color Palette
/// 100% Identical to ndika-nime web application CSS design variables
class AppColors {
  // Base Canvas & Surfaces
  static const Color ink = Color(0xFF0B0B10);       // --ink: #0b0b10 (Deep OLED Obsidian)
  static const Color ink2 = Color(0xFF141419);      // --ink-2: #141419
  static const Color panel = Color(0xFF181820);     // --panel: #181820 (Card panels)
  static const Color panelElevated = Color(0xFF1F1F2A);

  // Signatures Accents
  static const Color gold = Color(0xFFD4A73C);      // --gold: #d4a73c (Signature Ndichan Gold)
  static const Color ember = Color(0xFFFF4E2D);     // --ember: #ff4e2d (Live, Action, Trending)
  static const Color bone = Color(0xFFF0EAD9);      // --bone: #f0ead9 (Warm white)

  // Typography & Borders
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF8A8A97); // --muted: #8a8a97
  static const Color line = Color(0xFF2A2A35);      // --line: #2a2a35

  // Gradients
  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, ember],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroOverlayGradient = LinearGradient(
    colors: [ink, Colors.transparent],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  );
}
