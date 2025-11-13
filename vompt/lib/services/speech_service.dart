import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  // Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        return false;
      }

      // Initialize speech recognition
      _isInitialized = await _speech.initialize(
        onError: (error) {
          // Handle error silently or use a proper logger
        },
        onStatus: (status) {
          // Handle status silently or use a proper logger
        },
      );

      return _isInitialized;
    } catch (e) {
      // Handle error silently or use a proper logger
      return false;
    }
  }

  // Start listening
  Future<bool> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          } else if (onPartialResult != null) {
            onPartialResult(result.recognizedWords);
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
      return true;
    } catch (e) {
      // Handle error silently or use a proper logger
      return false;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  // Cancel listening
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
    }
  }

  // Check if speech recognition is available
  Future<bool> isAvailable() async {
    return await _speech.initialize();
  }

  // Get available locales
  Future<List<String>> getLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final locales = await _speech.locales();
    return locales.map((locale) => locale.localeId).toList();
  }

  // Dispose
  void dispose() {
    stopListening();
  }
}
