import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class IntelligentSpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Track speech patterns for speed adjustment
  final List<DateTime> _wordTimestamps = [];
  double _averageWordsPerMinute = 150.0; // Default reading speed
  
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  double get wordsPerMinute => _averageWordsPerMinute;

  // Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('🎤 Requesting microphone permission...');
      final status = await Permission.microphone.request();
      print('🎤 Permission status: $status');
      
      if (!status.isGranted) {
        print('❌ Microphone permission denied');
        return false;
      }

      print('🎤 Initializing speech recognition...');
      
      // Add timeout to prevent hanging
      _isInitialized = await _speech.initialize(
        onError: (error) {
          print('❌ Speech error: ${error.errorMsg}');
        },
        onStatus: (status) {
          print('🎤 Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        debugLogging: true,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ Speech initialization timed out');
          return false;
        },
      );

      print('🎤 Speech initialized: $_isInitialized');
      
      if (!_isInitialized) {
        print('❌ Speech recognition not available on this device');
        return false;
      }
      
      print('✅ Speech ready to listen');
      
      return _isInitialized;
    } catch (e) {
      print('❌ Failed to initialize speech: $e');
      return false;
    }
  }

  // Start listening with intelligent word tracking
  Future<bool> startListening({
    required Function(String recognizedWord, List<String> allWords) onWordRecognized,
    required Function(double wpm) onSpeedUpdate,
    Function()? onStopped,
  }) async {
    if (!_isInitialized) {
      print('🎤 Not initialized, initializing now...');
      final initialized = await initialize();
      if (!initialized) {
        print('❌ Failed to initialize');
        return false;
      }
    }

    if (_isListening) {
      print('🎤 Already listening, stopping first...');
      await stopListening();
    }

    try {
      print('🎤 Starting to listen...');
      await _speech.listen(
        onResult: (result) {
          print('🎤 Recognized: ${result.recognizedWords}');
          final words = result.recognizedWords.split(' ');
          
          // Track word timing
          if (words.isNotEmpty) {
            _wordTimestamps.add(DateTime.now());
            _calculateReadingSpeed();
            onSpeedUpdate(_averageWordsPerMinute);
          }
          
          // Send recognized words
          if (words.isNotEmpty) {
            onWordRecognized(words.last, words);
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: false,
          onDevice: true, // Use on-device recognition for privacy
        ),
      );

      _isListening = true;
      print('✅ Now listening!');
      return true;
    } catch (e) {
      print('❌ Failed to start listening: $e');
      return false;
    }
  }

  // Calculate reading speed based on word timestamps
  void _calculateReadingSpeed() {
    if (_wordTimestamps.length < 5) return; // Need at least 5 words for accurate calculation
    
    // Keep only last 20 words for rolling average
    if (_wordTimestamps.length > 20) {
      _wordTimestamps.removeAt(0);
    }
    
    // Calculate words per minute from timestamps
    final duration = _wordTimestamps.last.difference(_wordTimestamps.first);
    if (duration.inSeconds > 0) {
      final wordsPerSecond = (_wordTimestamps.length - 1) / duration.inSeconds;
      _averageWordsPerMinute = wordsPerSecond * 60;
      
      // Clamp to reasonable values
      _averageWordsPerMinute = _averageWordsPerMinute.clamp(60.0, 300.0);
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      _wordTimestamps.clear();
    }
  }

  // Cancel listening
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
      _wordTimestamps.clear();
    }
  }

  // Reset speed tracking
  void resetSpeedTracking() {
    _wordTimestamps.clear();
    _averageWordsPerMinute = 150.0;
  }

  // Dispose
  void dispose() {
    stopListening();
  }
}
