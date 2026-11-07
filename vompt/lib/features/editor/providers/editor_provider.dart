import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/text_processor.dart';
import '../../../data/models/document.dart';

/// Editing state for one script, saved automatically a moment after typing stops.
class EditorProvider with ChangeNotifier {
  Document? _currentDocument;
  String _currentContent = '';
  String _currentTitle = '';
  int _revision = 0;
  int _savedRevision = 0;
  bool _isSaving = false;
  Timer? _autoSaveTimer;
  Future<void> Function(Document)? _persist;

  static const Duration autoSaveDelay = Duration(milliseconds: 1200);

  Document? get currentDocument => _currentDocument;
  String get currentContent => _currentContent;
  String get currentTitle => _currentTitle;
  bool get hasUnsavedChanges => _revision != _savedRevision;
  bool get isSaving => _isSaving;

  int get wordCount => TextProcessor.countWords(_currentContent);
  int get characterCount => _currentContent.length;
  double get estimatedReadingTime =>
      TextProcessor.estimateReadingTime(_currentContent);

  void loadDocument(
    Document document, {
    required Future<void> Function(Document) persist,
  }) {
    _autoSaveTimer?.cancel();
    _currentDocument = document;
    _currentContent = document.content;
    _currentTitle = document.title;
    _revision = _savedRevision = 0;
    _isSaving = false;
    _persist = persist;
  }

  void updateContent(String content) {
    if (_currentContent == content) return;
    _currentContent = content;
    _changed();
  }

  void updateTitle(String title) {
    final next = title.trim().isEmpty ? 'Untitled script' : title.trim();
    if (_currentTitle == next) return;
    _currentTitle = next;
    _changed();
  }

  void _changed() {
    _revision++;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(autoSaveDelay, save);
    notifyListeners();
  }

  /// Saves now if anything changed. Edits made during a save are kept and
  /// saved by the next timer.
  Future<void> save() async {
    _autoSaveTimer?.cancel();
    final persist = _persist;
    if (!hasUnsavedChanges ||
        _isSaving ||
        persist == null ||
        _currentDocument == null) {
      return;
    }
    final revision = _revision;
    final doc = getUpdatedDocument();
    _isSaving = true;
    notifyListeners();
    try {
      await persist(doc);
      _currentDocument = doc;
      _savedRevision = revision;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    if (hasUnsavedChanges) _autoSaveTimer = Timer(autoSaveDelay, save);
  }

  Document getUpdatedDocument() {
    final doc = _currentDocument;
    if (doc == null) throw StateError('No document loaded');
    return doc.copyWith(
      title: _currentTitle,
      content: _currentContent,
      modifiedAt: DateTime.now(),
    );
  }

  void clear() {
    _autoSaveTimer?.cancel();
    _currentDocument = null;
    _currentContent = '';
    _currentTitle = '';
    _revision = _savedRevision = 0;
    _isSaving = false;
    _persist = null;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
