import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/document.dart';
import '../../core/constants/app_constants.dart';

class DocumentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Create a new document
  Future<Document> create(Document document) async {
    final db = await _dbHelper.database;
    await db.insert(
      AppConstants.documentsTable,
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return document;
  }

  // Read a single document by ID
  Future<Document?> read(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.documentsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Document.fromMap(maps.first);
  }

  // Read all documents
  Future<List<Document>> readAll() async {
    final db = await _dbHelper.database;
    const orderBy = 'modifiedAt DESC';
    final result = await db.query(
      AppConstants.documentsTable,
      orderBy: orderBy,
    );

    return result.map((map) => Document.fromMap(map)).toList();
  }

  // Update a document
  Future<int> update(Document document) async {
    final db = await _dbHelper.database;
    return db.update(
      AppConstants.documentsTable,
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  // Delete a document
  Future<int> delete(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.documentsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Search documents by title or content
  Future<List<Document>> search(String query) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      AppConstants.documentsTable,
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'modifiedAt DESC',
    );

    return result.map((map) => Document.fromMap(map)).toList();
  }

  // Get document count
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.documentsTable}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Delete all documents
  Future<int> deleteAll() async {
    final db = await _dbHelper.database;
    return await db.delete(AppConstants.documentsTable);
  }
}
