import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/document.dart';
import '../../../data/models/teleprompter_settings.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/constants/app_constants.dart';

class TeleprompterProvider with ChangeNotifier {
  final SettingsRepository _settingsRepository = SettingsRepository();
  final ScrollController scrollController = ScrollController();

  Document? _currentDocument;
  TeleprompterSettings _settings = TeleprompterSettings.defaultSettings;
  bool _isPlaying = false;
  bool _isSpeechRecognitionActive = false;
  bool _isOverlayVisible = true;
  int _currentWordIndex = 0;
  Timer? _scrollTimer;
  Timer? _overlayTimer;

  Document? get currentDocument => _currentDocument;
  TeleprompterSettings get settings => _settings;
  bool get isPlaying => _isPlaying;
  bool get isSpeechRecognitionActive => _isSpeechRecognitionActive;
  bool get isOverlayVisible => _isOverlayVisible;
  int get currentWordIndex => _currentWordIndex;

  // Load document and settings
  Future<void> loadDocument(Document document) async {
    _currentDocument = document;
    _settings = await _settingsRepository.getSettings();
    _currentWordIndex = 0;
    _isPlaying = false;
    _isSpeechRecognitionActive = false;
    _isOverlayVisible = true;
    _startOverlayTimer();
    notifyListeners();
  }

  // Toggle play/pause
  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
    _showOverlay();
    notifyListeners();
  }

  // Start auto-scroll
  void _startAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(
      const Duration(milliseconds: 16), // 60fps
      (_) {
        if (scrollController.hasClients) {
          final newOffset = scrollController.offset + _settings.scrollSpeed;
          if (newOffset < scrollController.position.maxScrollExtent) {
            scrollController.jumpTo(newOffset);
          } else {
            // Reached end
            _isPlaying = false;
            _stopAutoScroll();
            notifyListeners();
          }
        }
      },
    );
  }

  // Stop auto-scroll
  void _stopAutoScroll() {
    _scrollTimer?.cancel();
  }

  // Update scroll speed
  void updateScrollSpeed(double speed) {
    _settings = _settings.copyWith(scrollSpeed: speed);
    _settingsRepository.updateScrollSpeed(speed);
    if (_isPlaying) {
      _startAutoScroll(); // Restart with new speed
    }
    _showOverlay();
    notifyListeners();
  }

  // Update font size
  void updateFontSize(double size) {
    _settings = _settings.copyWith(fontSize: size);
    _settingsRepository.updateFontSize(size);
    _showOverlay();
    notifyListeners();
  }

  // Toggle mirror mode
  void toggleMirrorMode() {
    _settings = _settings.copyWith(mirrorMode: !_settings.mirrorMode);
    _settingsRepository.updateMirrorMode(_settings.mirrorMode);
    _showOverlay();
    notifyListeners();
  }

  // Toggle dark mode
  void toggleDarkMode() {
    _settings = _settings.copyWith(darkMode: !_settings.darkMode);
    _settingsRepository.updateDarkMode(_settings.darkMode);
    _showOverlay();
    notifyListeners();
  }

  // Toggle speech recognition
  void toggleSpeechRecognition() {
    _isSpeechRecognitionActive = !_isSpeechRecognitionActive;
    _settingsRepository.updateSpeechRecognition(_isSpeechRecognitionActive);
    _showOverlay();
    notifyListeners();
  }

  // Update current word index (for speech recognition)
  void updateCurrentWordIndex(int index) {
    _currentWordIndex = index;
    notifyListeners();
  }

  // Scroll to word
  void scrollToWord(int wordIndex) {
    // Calculate approximate position
    // This is simplified - in real implementation would need precise calculation
    if (scrollController.hasClients && _currentDocument != null) {
      final totalWords = _currentDocument!.wordCount;
      if (totalWords > 0) {
        final maxScroll = scrollController.position.maxScrollExtent;
        final targetScroll = (wordIndex / totalWords) * maxScroll;
        scrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // Toggle overlay visibility
  void toggleOverlay() {
    _isOverlayVisible = !_isOverlayVisible;
    if (_isOverlayVisible) {
      _startOverlayTimer();
    } else {
      _overlayTimer?.cancel();
    }
    notifyListeners();
  }

  // Show overlay and start auto-hide timer
  void _showOverlay() {
    _isOverlayVisible = true;
    _startOverlayTimer();
    notifyListeners();
  }

  // Start overlay auto-hide timer
  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(
      const Duration(milliseconds: AppConstants.uiAutoHideDuration),
      () {
        _isOverlayVisible = false;
        notifyListeners();
      },
    );
  }

  // Show settings (placeholder)
  void showSettings() {
    _showOverlay();
    // TODO: Implement settings dialog
  }

  // Reset to beginning
  void reset() {
    _currentWordIndex = 0;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    _showOverlay();
    notifyListeners();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _overlayTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }
}
