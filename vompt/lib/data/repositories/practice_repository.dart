import '../database/database_helper.dart';
import '../models/practice_session.dart';
import '../../core/constants/app_constants.dart';

class PracticeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> save(PracticeSession session) async {
    final db = await _dbHelper.database;
    await db.insert(AppConstants.practiceTable, session.toMap());
  }

  /// Takes of one script, newest first.
  Future<List<PracticeSession>> forDocument(String documentId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      AppConstants.practiceTable,
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(PracticeSession.fromMap).toList();
  }

  /// The most recent take of each script, keyed by document id.
  Future<Map<String, PracticeSession>> latestByDocument() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT p.* FROM ${AppConstants.practiceTable} p
      JOIN (
        SELECT documentId, MAX(createdAt) AS latest
        FROM ${AppConstants.practiceTable} GROUP BY documentId
      ) l ON p.documentId = l.documentId AND p.createdAt = l.latest
    ''');
    return {
      for (final r in rows)
        r['documentId'] as String: PracticeSession.fromMap(r),
    };
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      AppConstants.practiceTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteForDocument(String documentId) async {
    final db = await _dbHelper.database;
    await db.delete(
      AppConstants.practiceTable,
      where: 'documentId = ?',
      whereArgs: [documentId],
    );
  }
}
