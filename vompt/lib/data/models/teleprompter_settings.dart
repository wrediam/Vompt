import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/colors.dart';

class TeleprompterSettings {
  final double fontSize;
  final double scrollSpeed;
  final bool mirrorMode;
  final bool darkMode;
  final bool speechRecognitionEnabled;
  final Color highlightColor;
  final double textPadding;

  TeleprompterSettings({
    this.fontSize = AppConstants.defaultFontSize,
    this.scrollSpeed = AppConstants.defaultScrollSpeed,
    this.mirrorMode = false,
    this.darkMode = false,
    this.speechRecognitionEnabled = false,
    this.highlightColor = AppColors.lightHighlight,
    this.textPadding = AppConstants.defaultTextPadding,
  });

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'scrollSpeed': scrollSpeed,
      'mirrorMode': mirrorMode ? 1 : 0,
      'darkMode': darkMode ? 1 : 0,
      'speechRecognitionEnabled': speechRecognitionEnabled ? 1 : 0,
      'highlightColor': highlightColor.toARGB32(),
      'textPadding': textPadding,
    };
  }

  // Create from Map
  factory TeleprompterSettings.fromMap(Map<String, dynamic> map) {
    return TeleprompterSettings(
      fontSize: map['fontSize'] as double? ?? AppConstants.defaultFontSize,
      scrollSpeed: map['scrollSpeed'] as double? ?? AppConstants.defaultScrollSpeed,
      mirrorMode: (map['mirrorMode'] as int? ?? 0) == 1,
      darkMode: (map['darkMode'] as int? ?? 0) == 1,
      speechRecognitionEnabled: (map['speechRecognitionEnabled'] as int? ?? 0) == 1,
      highlightColor: Color(map['highlightColor'] as int? ?? AppColors.lightHighlight.toARGB32()),
      textPadding: map['textPadding'] as double? ?? AppConstants.defaultTextPadding,
    );
  }

  // Convert to JSON for web API
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'scrollSpeed': scrollSpeed,
      'mirrorMode': mirrorMode,
      'darkMode': darkMode,
      'speechRecognitionEnabled': speechRecognitionEnabled,
      'highlightColor': '#${highlightColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
      'textPadding': textPadding,
    };
  }

  // Copy with method
  TeleprompterSettings copyWith({
    double? fontSize,
    double? scrollSpeed,
    bool? mirrorMode,
    bool? darkMode,
    bool? speechRecognitionEnabled,
    Color? highlightColor,
    double? textPadding,
  }) {
    return TeleprompterSettings(
      fontSize: fontSize ?? this.fontSize,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      mirrorMode: mirrorMode ?? this.mirrorMode,
      darkMode: darkMode ?? this.darkMode,
      speechRecognitionEnabled: speechRecognitionEnabled ?? this.speechRecognitionEnabled,
      highlightColor: highlightColor ?? this.highlightColor,
      textPadding: textPadding ?? this.textPadding,
    );
  }

  // Default settings
  static TeleprompterSettings get defaultSettings => TeleprompterSettings();

  @override
  String toString() {
    return 'TeleprompterSettings(fontSize: $fontSize, scrollSpeed: $scrollSpeed, mirrorMode: $mirrorMode, darkMode: $darkMode, speechEnabled: $speechRecognitionEnabled)';
  }
}
