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
        textPadding $realType,
        showStats INTEGER NOT NULL DEFAULT 1,
        centerText INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await _createPracticeTable(db);

    // A first script that teaches the app while you read it aloud.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(AppConstants.documentsTable, {
      'id': 'welcome',
      'title': 'Welcome to Vompt',
      'content': _welcomeScript,
      'createdAt': now,
      'modifiedAt': now,
    });

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
    if (oldVersion < 2) {
      await _createPracticeTable(db);
      await db.execute(
        'ALTER TABLE ${AppConstants.settingsTable} ADD COLUMN showStats INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.settingsTable} ADD COLUMN centerText INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future<void> _createPracticeTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.practiceTable} (
        id TEXT PRIMARY KEY,
        documentId TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        durationSeconds REAL NOT NULL,
        wordsPerMinute REAL NOT NULL,
        fillers TEXT NOT NULL,
        skippedWords INTEGER NOT NULL,
        misreads INTEGER NOT NULL,
        repeats INTEGER NOT NULL,
        longPauses INTEGER NOT NULL,
        accuracy REAL NOT NULL,
        completion REAL NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_practice_document ON ${AppConstants.practiceTable} (documentId, createdAt)',
    );
  }

  static const _welcomeScript =
      'Welcome to Vompt. Tap Rehearse, then Start, and read this out loud.\n\n'
      'Notice how the screen follows your voice. The word you are on lights up, and the '
      'script scrolls on its own. If you skip a line or go back, Vompt catches up after '
      'a few words.\n\n'
      'When you finish, you will see your pace, the fillers you used, and anything you '
      'skipped.\n\n'
      'Long-press any word to continue from there. Tap the screen to show or hide the '
      'controls.\n\n'
      'Now replace this with your own script, and have a great take.';

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
