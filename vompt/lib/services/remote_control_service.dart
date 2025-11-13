import 'dart:async';

/// Service to handle remote control commands from the web interface
/// This acts as a bridge between the web server and the teleprompter provider
class RemoteControlService {
  static final RemoteControlService _instance = RemoteControlService._internal();
  factory RemoteControlService() => _instance;
  RemoteControlService._internal();

  // Stream controllers for control commands
  final _startSpeechController = StreamController<void>.broadcast();
  final _stopSpeechController = StreamController<void>.broadcast();
  final _resetController = StreamController<void>.broadcast();
  final _fontSizeIncreaseController = StreamController<void>.broadcast();
  final _fontSizeDecreaseController = StreamController<void>.broadcast();
  final _mirrorToggleController = StreamController<void>.broadcast();
  final _clientConnectedController = StreamController<bool>.broadcast();
  final _documentSelectedController = StreamController<String>.broadcast();
  final _controlExitController = StreamController<void>.broadcast();

  // Track active connections and state
  bool _hasActiveClient = false;
  String? _selectedDocumentId;
  Timer? _heartbeatTimeout;
  static const _heartbeatTimeoutDuration = Duration(seconds: 10);
  
  // Track teleprompter state for web preview
  int _currentWordIndex = -1;
  bool _isActive = false;
  double _fontSize = 32.0;
  double _screenWidth = 932.0;  // Default landscape width for iPhone 14 Pro Max
  double _screenHeight = 430.0; // Default landscape height for iPhone 14 Pro Max

  // Streams for listening to control commands
  Stream<void> get onStartSpeech => _startSpeechController.stream;
  Stream<void> get onStopSpeech => _stopSpeechController.stream;
  Stream<void> get onReset => _resetController.stream;
  Stream<void> get onFontSizeIncrease => _fontSizeIncreaseController.stream;
  Stream<void> get onFontSizeDecrease => _fontSizeDecreaseController.stream;
  Stream<void> get onMirrorToggle => _mirrorToggleController.stream;
  Stream<bool> get onClientConnectionChange => _clientConnectedController.stream;
  Stream<String> get onDocumentSelected => _documentSelectedController.stream;
  Stream<void> get onControlExit => _controlExitController.stream;

  // Getters
  bool get hasActiveClient => _hasActiveClient;
  String? get selectedDocumentId => _selectedDocumentId;
  int get currentWordIndex => _currentWordIndex;
  bool get isActive => _isActive;
  double get fontSize => _fontSize;
  double get screenWidth => _screenWidth;
  double get screenHeight => _screenHeight;

  // Methods to trigger control commands (called by web server)
  void startSpeech() {
    _startSpeechController.add(null);
  }

  void stopSpeech() {
    _stopSpeechController.add(null);
  }

  void reset() {
    _resetController.add(null);
  }

  void increaseFontSize() {
    _fontSizeIncreaseController.add(null);
  }

  void decreaseFontSize() {
    _fontSizeDecreaseController.add(null);
  }

  void toggleMirror() {
    _mirrorToggleController.add(null);
  }

  void setClientConnected(bool connected) {
    // Only emit event if the connection state actually changed
    if (_hasActiveClient != connected) {
      _hasActiveClient = connected;
      _clientConnectedController.add(connected);
    }
    
    // Reset the heartbeat timeout timer
    _heartbeatTimeout?.cancel();
    
    if (connected) {
      // Set a timeout to detect disconnection
      _heartbeatTimeout = Timer(_heartbeatTimeoutDuration, () {
        // No heartbeat received within timeout period - client disconnected
        if (_hasActiveClient) {
          _hasActiveClient = false;
          _clientConnectedController.add(false);
        }
      });
    }
  }

  void selectDocument(String documentId) {
    _selectedDocumentId = documentId;
    _documentSelectedController.add(documentId);
  }

  void updateTeleprompterState(int wordIndex, bool active, {double? fontSize, double? screenWidth, double? screenHeight}) {
    _currentWordIndex = wordIndex;
    _isActive = active;
    if (fontSize != null) _fontSize = fontSize;
    if (screenWidth != null) _screenWidth = screenWidth;
    if (screenHeight != null) _screenHeight = screenHeight;
  }

  void exitControl() {
    _controlExitController.add(null);
  }

  void dispose() {
    _heartbeatTimeout?.cancel();
    _startSpeechController.close();
    _stopSpeechController.close();
    _resetController.close();
    _fontSizeIncreaseController.close();
    _fontSizeDecreaseController.close();
    _mirrorToggleController.close();
    _clientConnectedController.close();
    _documentSelectedController.close();
    _controlExitController.close();
  }
}
