import 'package:flutter/material.dart';

class AppColors {
  // Light Mode
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF000000);
  static const Color lightAccent = Color(0xFF007AFF); // iOS blue
  static const Color lightHighlight = Color(0xFFFFD700); // Gold for current word
  static const Color lightMuted = Color(0xFF8E8E93);
  static const Color lightSecondary = Color(0xFFF2F2F7);
  
  // Dark Mode
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkAccent = Color(0xFF0A84FF);
  static const Color darkHighlight = Color(0xFFFFA500); // Orange for current word
  static const Color darkMuted = Color(0xFF8E8E93);
  static const Color darkSecondary = Color(0xFF1C1C1E);
  
  // Status Colors
  static const Color success = Color(0xFF34C759);
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);
  
  // Teleprompter Specific
  static const Color teleprompterOverlay = Color(0x80000000); // Semi-transparent black
}
