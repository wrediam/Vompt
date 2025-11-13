import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../services/intelligent_speech_service.dart';
import '../../../services/remote_control_service.dart';

class IntelligentTeleprompterProvider with ChangeNotifier {
  final IntelligentSpeechService _speechService = IntelligentSpeechService();
  final RemoteControlService _remoteControlService = RemoteControlService();
  double _screenWidth = 0.0;
  double _screenHeight = 0.0;
  
  // Subscriptions for remote control
  StreamSubscription<void>? _playSubscription;
  StreamSubscription<void>? _pauseSubscription;
  StreamSubscription<void>? _resetSubscription;
  StreamSubscription<void>? _speedSubscription;
  StreamSubscription<void>? _fontSizeSubscription;
  StreamSubscription<void>? _mirrorSubscription;
  
  // Script and tracking
  String _scriptContent = '';
  List<String> _scriptWords = [];
  int _currentWordIndex = 0;
  
  // Settings
  double _fontSize = 32.0;
  bool _isMirrored = false;
  bool _isSpeechActive = false;
  
  // Scroll control
  double _scrollPosition = 0.0;
  double _scrollSpeed = 0.0; // Pixels per second, calculated from speech
  bool _isScrolling = false;
  
  // Getters
  String get scriptContent => _scriptContent;
  List<String> get scriptWords => _scriptWords;
  int get currentWordIndex => _currentWordIndex;
  double get fontSize => _fontSize;
  bool get isMirrored => _isMirrored;
  bool get isSpeechActive => _isSpeechActive;
  double get scrollPosition => _scrollPosition;
  double get scrollSpeed => _scrollSpeed;
  bool get isScrolling => _isScrolling;
  RemoteControlService get remoteControlService => _remoteControlService;
  
  // Load script
  void loadScript(String content) {
    _scriptContent = content;
    // Normalize whitespace and split - this ensures consistent word splitting
    final normalizedContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    _scriptWords = normalizedContent.split(' ');
    _currentWordIndex = -1; // Start at -1 so no word is highlighted initially
    _scrollPosition = 0.0;
    print('📄 Loaded script with ${_scriptWords.length} words');
    print('📄 First 10 words: ${_scriptWords.take(10).toList()}');
    print('📄 Content sample: ${content.substring(0, content.length > 200 ? 200 : content.length)}');
    
    // Initialize remote control listeners
    _initializeRemoteControl();
    
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  // Initialize remote control listeners
  void _initializeRemoteControl() {
    // Cancel existing subscriptions
    _playSubscription?.cancel();
    _pauseSubscription?.cancel();
    _resetSubscription?.cancel();
    _speedSubscription?.cancel();
    _fontSizeSubscription?.cancel();
    _mirrorSubscription?.cancel();
    
    // Subscribe to remote control events
    _playSubscription = _remoteControlService.onStartSpeech.listen((_) {
      print('🎮 Remote: Start speech command received');
      startSpeechRecognition();
    });
    
    _pauseSubscription = _remoteControlService.onStopSpeech.listen((_) {
      print('🎮 Remote: Stop speech command received');
      stopSpeechRecognition();
    });
    
    _resetSubscription = _remoteControlService.onReset.listen((_) {
      print('🎮 Remote: Reset command received');
      reset();
    });
    
    _speedSubscription = _remoteControlService.onFontSizeIncrease.listen((_) {
      print('🎮 Remote: Font size increase');
      increaseFontSize();
    });
    
    _fontSizeSubscription = _remoteControlService.onFontSizeDecrease.listen((_) {
      print('🎮 Remote: Font size decrease');
      decreaseFontSize();
    });
    
    _mirrorSubscription = _remoteControlService.onMirrorToggle.listen((_) {
      print('🎮 Remote: Mirror toggle');
      toggleMirror();
    });
  }
  
  // Font size control
  void setFontSize(double size) {
    _fontSize = size.clamp(16.0, 72.0);
    print('📏 Font size set to: $_fontSize');
    notifyListeners();
  }
  
  void increaseFontSize() {
    print('📏 Increasing font size from $_fontSize to ${_fontSize + 2}');
    setFontSize(_fontSize + 2);
  }
  
  void decreaseFontSize() {
    print('📏 Decreasing font size from $_fontSize to ${_fontSize - 2}');
    setFontSize(_fontSize - 2);
  }
  
  // Mirror mode
  void toggleMirror() {
    _isMirrored = !_isMirrored;
    print('🪞 Mirror toggled: $_isMirrored');
    notifyListeners();
  }
  
  // Speech control
  Future<bool> startSpeechRecognition() async {
    if (_isSpeechActive) return true;
    
    // Update UI immediately
    _isSpeechActive = true;
    _isScrolling = true;
    _recentSpokenWords.clear(); // Reset context when starting
    notifyListeners();
    
    final success = await _speechService.startListening(
      onWordRecognized: _handleWordRecognized,
      onSpeedUpdate: _handleSpeedUpdate,
    );
    
    if (!success) {
      _isSpeechActive = false;
      _isScrolling = false;
      notifyListeners();
    }
    
    return success;
  }
  
  Future<void> stopSpeechRecognition() async {
    await _speechService.stopListening();
    _isSpeechActive = false;
    _isScrolling = false;
    _recentSpokenWords.clear(); // Clear context when stopping
    notifyListeners();
  }
  
  // Track recent spoken words for context matching
  final List<String> _recentSpokenWords = [];
  static const int _contextWindowSize = 3;

  void updateScreenDimensions(double width, double height) {
    _screenWidth = width;
    _screenHeight = height;
    // Immediately update remote control service with dimensions
    _remoteControlService.updateTeleprompterState(
      _currentWordIndex,
      _isSpeechActive,
      fontSize: _fontSize,
      screenWidth: _screenWidth,
      screenHeight: _screenHeight,
    );
    print('📱 Updated screen dimensions: ${width}x$height');
  }

  void _processSpeechResult(String word) {
    print('🎯 Recognized: "$word"');
    
    // Find the word in the script
    final normalizedWord = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '').trim();
    if (normalizedWord.isEmpty || normalizedWord.length < 2) return;
    
    // Add to recent spoken words
    _recentSpokenWords.add(normalizedWord);
    if (_recentSpokenWords.length > _contextWindowSize) {
      _recentSpokenWords.removeAt(0);
    }
    
    // Search in a window around current position
    final startIndex = _currentWordIndex < 0 ? 0 : (_currentWordIndex - 2).clamp(0, _scriptWords.length);
    final endIndex = (startIndex + 50).clamp(0, _scriptWords.length);
    
    // First pass: Look for exact matches with context verification
    for (int i = startIndex; i < endIndex; i++) {
      final scriptWord = _scriptWords[i].toLowerCase().replaceAll(RegExp(r'[^\w]'), '').trim();
      
      // Skip empty words and punctuation-only
      if (scriptWord.isEmpty || scriptWord.length < 2) continue;
      
      if (scriptWord == normalizedWord) {
        // Verify context: check if previous words match
        if (_verifyContext(i)) {
          print('✅ Exact match at index $i: "${_scriptWords[i]}" (context verified)');
          _currentWordIndex = i;
          _isScrolling = true;
          _remoteControlService.updateTeleprompterState(
            _currentWordIndex, 
            _isSpeechActive,
            fontSize: _fontSize,
            screenWidth: _screenWidth,
            screenHeight: _screenHeight,
          );
          notifyListeners();
          return;
        } else {
          print('⚠️ Match found at index $i but context mismatch - likely ad-libbing');
        }
      }
    }
    
    // Second pass: Look for partial matches with context verification
    if (normalizedWord.length >= 4) {
      for (int i = startIndex; i < endIndex; i++) {
        final scriptWord = _scriptWords[i].toLowerCase().replaceAll(RegExp(r'[^\w]'), '').trim();
        
        if (scriptWord.isEmpty || scriptWord.length < 4) continue;
        
        if (scriptWord.startsWith(normalizedWord) && scriptWord.length > normalizedWord.length) {
          if (_verifyContext(i)) {
            print('✅ Partial match at index $i: "${_scriptWords[i]}" (context verified)');
            _currentWordIndex = i;
            _isScrolling = true;
            _remoteControlService.updateTeleprompterState(
              _currentWordIndex, 
              _isSpeechActive,
              fontSize: _fontSize,
              screenWidth: _screenWidth,
              screenHeight: _screenHeight,
            );
            notifyListeners();
            return;
          }
        }
      }
    }
    
    print('❌ No match found for: "$word" (or context mismatch)');
  }
  
  bool _verifyContext(int candidateIndex) {
    // If we don't have enough spoken words yet, allow the match
    if (_recentSpokenWords.length < 2) return true;
    
    // Check if the previous spoken words match the script before this position
    int matchCount = 0;
    final wordsToCheck = _recentSpokenWords.length - 1; // Don't include current word
    
    for (int i = 0; i < wordsToCheck; i++) {
      final spokenWordIndex = _recentSpokenWords.length - 2 - i; // -2 to skip current word
      final scriptWordIndex = candidateIndex - 1 - i;
      
      if (scriptWordIndex < 0) break;
      
      final spokenWord = _recentSpokenWords[spokenWordIndex];
      final scriptWord = _scriptWords[scriptWordIndex].toLowerCase().replaceAll(RegExp(r'[^\w]'), '').trim();
      
      if (scriptWord.isEmpty) continue;
      
      // Check if words match (exact or partial)
      if (scriptWord == spokenWord || scriptWord.startsWith(spokenWord)) {
        matchCount++;
      }
    }
    
    // Require at least 2 out of 3 previous words to match for context verification
    final threshold = (wordsToCheck * 0.66).ceil();
    final verified = matchCount >= threshold;
    
    if (!verified) {
      print('🔍 Context check: $matchCount/$wordsToCheck words matched (need $threshold)');
    }
    
    return verified;
  }
  
  void _handleWordRecognized(String word, List<String> allRecognizedWords) {
    _processSpeechResult(word);
  }
  
  // Handle speed updates from speech recognition
  void _handleSpeedUpdate(double wpm) {
    // Convert words per minute to scroll speed
    // Assuming average word height + spacing = 40 pixels at default font size
    final pixelsPerWord = (_fontSize / 32.0) * 40.0;
    _scrollSpeed = (wpm / 60.0) * pixelsPerWord; // Pixels per second
    
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  // Update scroll position (called by animation controller)
  void updateScrollPosition(double position) {
    _scrollPosition = position;
    // Don't notify listeners here to avoid rebuild during animation
  }
  
  // Manual scroll control
  void pauseScrolling() {
    _isScrolling = false;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  void resumeScrolling() {
    _isScrolling = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  // Reset
  void reset() {
    _currentWordIndex = -1; // Start at -1 so no word is highlighted
    _scrollPosition = 0.0;
    _isScrolling = false;
    _speechService.resetSpeedTracking();
    print('🔄 Reset teleprompter');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  @override
  void dispose() {
    // Cancel remote control subscriptions
    _playSubscription?.cancel();
    _pauseSubscription?.cancel();
    _resetSubscription?.cancel();
    _speedSubscription?.cancel();
    _fontSizeSubscription?.cancel();
    _mirrorSubscription?.cancel();
    
    _speechService.dispose();
    super.dispose();
  }
}
