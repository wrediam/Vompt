import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/teleprompter_settings.dart';
import '../../core/constants/app_constants.dart';

class SettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const String _defaultId = 'default';

  // Get settings
  Future<TeleprompterSettings> getSettings() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.settingsTable,
      where: 'id = ?',
      whereArgs: [_defaultId],
    );

    if (maps.isEmpty) {
      // Return default settings if none exist
      return TeleprompterSettings.defaultSettings;
    }

    return TeleprompterSettings.fromMap(maps.first);
  }

  // Save settings
  Future<void> saveSettings(TeleprompterSettings settings) async {
    final db = await _dbHelper.database;
    final map = settings.toMap();
    map['id'] = _defaultId;

    await db.insert(
      AppConstants.settingsTable,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Update specific setting
  Future<void> updateFontSize(double fontSize) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(fontSize: fontSize));
  }

  Future<void> updateScrollSpeed(double scrollSpeed) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(scrollSpeed: scrollSpeed));
  }

  Future<void> updateMirrorMode(bool mirrorMode) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(mirrorMode: mirrorMode));
  }

  Future<void> updateDarkMode(bool darkMode) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(darkMode: darkMode));
  }

  Future<void> updateSpeechRecognition(bool enabled) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(speechRecognitionEnabled: enabled));
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    await saveSettings(TeleprompterSettings.defaultSettings);
  }
}
