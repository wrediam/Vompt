import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/document.dart';
import '../../../data/repositories/document_repository.dart';

class DocumentsProvider with ChangeNotifier {
  final DocumentRepository _repository = DocumentRepository();
  final Uuid _uuid = const Uuid();

  List<Document> _documents = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Document> get documents => _searchQuery.isEmpty
      ? _documents
      : _documents.where((doc) =>
          doc.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          doc.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  // Load all documents
  Future<void> loadDocuments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _documents = await _repository.readAll();
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
      _documents.removeWhere((doc) => doc.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete document: $e';
      notifyListeners();
      return false;
    }
  }

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
