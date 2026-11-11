import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/document.dart';
import '../models/script_version.dart';

class VersionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Versions kept per script; older ones are pruned.
  static const keepPerScript = 60;

  /// While editing, at most one automatic version per this interval.
  static const editInterval = Duration(minutes: 10);

  /// Versions of one script, newest first.
  Future<List<ScriptVersion>> forDocument(String documentId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      AppConstants.versionsTable,
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(ScriptVersion.fromMap).toList();
  }

  Future<ScriptVersion?> latest(String documentId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      AppConstants.versionsTable,
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ScriptVersion.fromMap(rows.first);
  }

  /// Saves [doc]'s text as a version, unless it is empty, identical to the
  /// newest version, or (with [minGap]) the newest version is that recent.
  /// The first version of a script is always [VersionKind.original].
  Future<ScriptVersion?> checkpoint(
    Document doc,
    VersionKind kind, {
    String? label,
    Duration? minGap,
  }) {
    // One at a time: two checkpoints racing could both see the text as new.
    final run = _queue.then(
      (_) => _checkpoint(doc, kind, label: label, minGap: minGap),
    );
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  static Future<void> _queue = Future.value();

  Future<ScriptVersion?> _checkpoint(
    Document doc,
    VersionKind kind, {
    String? label,
    Duration? minGap,
  }) async {
    if (doc.content.trim().isEmpty) return null;
    final newest = await latest(doc.id);
    if (newest != null) {
      if (newest.content == doc.content) return null;
      if (minGap != null &&
          DateTime.now().difference(newest.createdAt) < minGap) {
        return null;
      }
    }
    final version = ScriptVersion(
      id: const Uuid().v4(),
      documentId: doc.id,
      createdAt: DateTime.now(),
      title: doc.title,
      content: doc.content,
      kind: newest == null ? VersionKind.original : kind,
      label: newest == null ? null : label,
    );
    final db = await _dbHelper.database;
    await db.insert(AppConstants.versionsTable, version.toMap());
    await _prune(doc.id);
    return version;
  }

  Future<void> deleteForDocument(String documentId) async {
    final db = await _dbHelper.database;
    await db.delete(
      AppConstants.versionsTable,
      where: 'documentId = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> _prune(String documentId) async {
    final db = await _dbHelper.database;
    await db.rawDelete(
      '''
      DELETE FROM ${AppConstants.versionsTable}
      WHERE documentId = ? AND id NOT IN (
        SELECT id FROM ${AppConstants.versionsTable}
        WHERE documentId = ? ORDER BY createdAt DESC LIMIT ?
      )
      ''',
      [documentId, documentId, keepPerScript],
    );
  }
}
