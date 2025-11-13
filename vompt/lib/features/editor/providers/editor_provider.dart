import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../../../data/models/document.dart';
import '../../../core/utils/text_processor.dart';

class EditorProvider with ChangeNotifier {
  Document? _currentDocument;
  String _currentContent = '';
  String _currentTitle = '';
  bool _hasUnsavedChanges = false;
  Timer? _autoSaveTimer;
  bool _isSaving = false;
  bool _autoSaveReady = false;

  static const Duration autoSaveDelay = Duration(seconds: 2);

  Document? get currentDocument => _currentDocument;
  String get currentContent => _currentContent;
  String get currentTitle => _currentTitle;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get isSaving => _isSaving;

  int get wordCount => TextProcessor.countWords(_currentContent);
  int get characterCount => _currentContent.length;
  double get estimatedReadingTime => TextProcessor.estimateReadingTime(_currentContent);

  // Load document for editing
  void loadDocument(Document document) {
    _currentDocument = document;
    _currentContent = document.content;
    _currentTitle = document.title;
    _hasUnsavedChanges = false;
    // Defer notification to avoid calling during initState/build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Create new document
  void createNewDocument({String title = 'Untitled Document', String content = ''}) {
    _currentDocument = null;
    _currentTitle = title;
    _currentContent = content;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  // Update content
  void updateContent(String content) {
    if (_currentContent != content) {
      _currentContent = content;
      _hasUnsavedChanges = true;
      _scheduleAutoSave();
      // Defer notification to avoid calling during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // Update title
  void updateTitle(String title) {
    if (_currentTitle != title) {
      _currentTitle = title.isEmpty ? 'Untitled Document' : title;
      _hasUnsavedChanges = true;
      _scheduleAutoSave();
      // Defer notification to avoid calling during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // Schedule auto-save
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveReady = false;
    _autoSaveTimer = Timer(autoSaveDelay, () {
      _autoSaveReady = true;
      // Don't call notifyListeners here as it can cause build-time errors
    });
  }

  // Mark as saved
  void markAsSaved() {
    _hasUnsavedChanges = false;
    _isSaving = false;
    _autoSaveReady = false;
    notifyListeners();
  }

  // Mark as saving
  void markAsSaving() {
    _isSaving = true;
    _autoSaveReady = false;
    notifyListeners();
  }

  // Get updated document
  Document getUpdatedDocument() {
    if (_currentDocument == null) {
      throw Exception('No document loaded');
    }
    return _currentDocument!.copyWith(
      title: _currentTitle,
      content: _currentContent,
      modifiedAt: DateTime.now(),
    );
  }

  // Clear current document
  void clear() {
    _autoSaveTimer?.cancel();
    _currentDocument = null;
    _currentContent = '';
    _currentTitle = '';
    _hasUnsavedChanges = false;
    _isSaving = false;
    _autoSaveReady = false;
    // Don't notify listeners here as this is typically called during dispose
  }

  // Check if should trigger auto-save
  bool shouldAutoSave() {
    return _hasUnsavedChanges && !_isSaving && _autoSaveReady;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
