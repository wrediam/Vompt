import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.databaseName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    // Documents table
    await db.execute('''
      CREATE TABLE ${AppConstants.documentsTable} (
        id $idType,
        title $textType,
        content $textType,
        createdAt $integerType,
        modifiedAt $integerType
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE ${AppConstants.settingsTable} (
        id $idType,
        fontSize $realType,
        scrollSpeed $realType,
        mirrorMode $integerType,
        darkMode $integerType,
        speechRecognitionEnabled $integerType,
        highlightColor $integerType,
        textPadding $realType
      )
    ''');

    // Insert default settings
    await db.insert(AppConstants.settingsTable, {
      'id': 'default',
      'fontSize': AppConstants.defaultFontSize,
      'scrollSpeed': AppConstants.defaultScrollSpeed,
      'mirrorMode': 0,
      'darkMode': 0,
      'speechRecognitionEnabled': 0,
      'highlightColor': 0xFFFFD700, // Gold
      'textPadding': AppConstants.defaultTextPadding,
    });
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here in future versions
    if (oldVersion < newVersion) {
      // Add migration logic here
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
