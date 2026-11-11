import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/document.dart';
import '../../../data/models/practice_session.dart';
import '../../../data/repositories/document_repository.dart';
import '../../../data/models/script_version.dart';
import '../../../data/repositories/practice_repository.dart';
import '../../../data/repositories/version_repository.dart';
import '../../../services/remote_control_service.dart';

class DocumentsProvider with ChangeNotifier {
  DocumentsProvider() {
    // Scripts edited in the web remote land in storage directly; pick them up.
    _remoteSub = RemoteControlService().onDocumentsChanged.listen(
      (_) => _reloadQuietly(),
    );
  }

  final DocumentRepository _repository = DocumentRepository();
  StreamSubscription<void>? _remoteSub;
  final Uuid _uuid = const Uuid();

  List<Document> _documents = [];
  Map<String, PracticeSession> _latestTakes = {};
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Document> get documents => _searchQuery.isEmpty
      ? _documents
      : _documents
            .where(
              (doc) =>
                  doc.title.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  doc.content.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
            )
            .toList();

  bool get isLoading => _isLoading;

  /// The most recent practice take of a script, if any.
  PracticeSession? latestTake(String documentId) => _latestTakes[documentId];
  String? get error => _error;
  String get searchQuery => _searchQuery;

  // Load all documents
  Future<void> loadDocuments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _documents = await _repository.readAll();
      _latestTakes = await PracticeRepository().latestByDocument();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load documents: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new document
  Future<Document?> createDocument(String title, {String content = ''}) async {
    try {
      final now = DateTime.now();
      final document = Document(
        id: _uuid.v4(),
        title: title.isEmpty ? 'Untitled Document' : title,
        content: content,
        createdAt: now,
        modifiedAt: now,
      );

      await _repository.create(document);
      await VersionRepository().checkpoint(document, VersionKind.original);
      _documents.insert(0, document); // Add to beginning
      notifyListeners();
      return document;
    } catch (e) {
      _error = 'Failed to create document: $e';
      notifyListeners();
      return null;
    }
  }

  // Update document
  Future<bool> updateDocument(Document document) async {
    try {
      final updatedDoc = document.copyWith(modifiedAt: DateTime.now());
      await _repository.update(updatedDoc);

      final index = _documents.indexWhere((d) => d.id == document.id);
      if (index != -1) {
        _documents[index] = updatedDoc;
        // Move to top of list
        _documents.removeAt(index);
        _documents.insert(0, updatedDoc);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update document: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete document
  Future<bool> deleteDocument(String id) async {
    try {
      await _repository.delete(id);
      await PracticeRepository().deleteForDocument(id);
      await VersionRepository().deleteForDocument(id);
      _documents.removeWhere((doc) => doc.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete document: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _reloadQuietly() async {
    try {
      _documents = await _repository.readAll();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    super.dispose();
  }

  /// Refreshes practice results after a take, without a loading state.
  Future<void> refreshTakes() async {
    try {
      _latestTakes = await PracticeRepository().latestByDocument();
      notifyListeners();
    } catch (_) {}
  }

  /// Re-reads one document from storage (it may have been edited on the web).
  Future<Document?> reloadDocument(String id) async {
    final doc = await _repository.read(id);
    if (doc == null) return null;
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) {
      _documents.insert(0, doc);
    } else {
      _documents[index] = doc;
    }
    notifyListeners();
    return doc;
  }

  Future<Document?> duplicateDocument(Document source) =>
      createDocument('${source.title} copy', content: source.content);

  // Get document by ID
  Document? getDocument(String id) {
    try {
      return _documents.firstWhere((doc) => doc.id == id);
    } catch (e) {
      return null;
    }
  }

  // Search documents
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  // Get document count
  int get documentCount => _documents.length;

  // Check if has documents
  bool get hasDocuments => _documents.isNotEmpty;

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
