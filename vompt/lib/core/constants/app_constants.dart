class AppConstants {
  // App Info
  static const String appName = 'Vompt';
  static const String bundleId = 'com.vompt.ios';

  // Database
  static const String databaseName = 'vompt.db';
  static const int databaseVersion = 3;
  static const String documentsTable = 'documents';
  static const String settingsTable = 'settings';
  static const String practiceTable = 'practice_sessions';
  static const String versionsTable = 'script_versions';

  // Teleprompter Settings Defaults
  static const double defaultFontSize = 48.0;
  static const double minFontSize = 24.0;
  static const double maxFontSize = 72.0;

  static const double defaultScrollSpeed = 3.5;
  static const double minScrollSpeed = 0.0;
  static const double maxScrollSpeed = 10.0;

  static const double defaultTextPadding = 16.0;
  static const double defaultLineHeight = 1.6;
  static const double defaultLetterSpacing = 0.5;

  // UI
  static const double screenPadding = 16.0;
  static const double listItemHeight = 72.0;
  static const double buttonHeight = 48.0;
  static const double borderRadius = 12.0;
  static const double fabSize = 56.0;

  // Animations
  static const int pageTransitionDuration = 300;
  static const int wordHighlightDuration = 150;
  static const int uiAutoHideDuration = 3000;
  static const int fadeOutDuration = 500;

  // Web Server
  static const int defaultServerPort = 8080;
  static const String bonjourServiceType = '_vompt._tcp';
}
