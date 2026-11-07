import 'dart:async';

/// Service to handle remote control commands from the web interface
/// This acts as a bridge between the web server and the teleprompter provider
class RemoteControlService {
  static final RemoteControlService _instance =
      RemoteControlService._internal();
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
  final _finishTakeController = StreamController<void>.broadcast();
  final _documentsChangedController = StreamController<void>.broadcast();

  /// Supplies the current take state on demand (set by the teleprompter).
  Map<String, Object?> Function()? liveSource;

  // Track active connections and state
  bool _hasActiveClient = false;
  String? _selectedDocumentId;
  Timer? _heartbeatTimeout;
  // Browsers throttle timers in background tabs; allow for slow heartbeats.
  static const _heartbeatTimeoutDuration = Duration(seconds: 25);

  /// Whether a prompter screen is showing on the phone.
  bool prompterOpen = false;

  // Track teleprompter state for web preview
  int _currentWordIndex = -1;
  bool _isActive = false;
  bool _isMirrored = false;
  double _fontSize = 32.0;
  double _screenWidth = 932.0; // Default landscape width for iPhone 14 Pro Max
  double _screenHeight =
      430.0; // Default landscape height for iPhone 14 Pro Max
  int _fillerCount = 0;
  double _wordsPerMinute = 0;
  int _elapsedSeconds = 0;

  // Streams for listening to control commands
  Stream<void> get onStartSpeech => _startSpeechController.stream;
  Stream<void> get onStopSpeech => _stopSpeechController.stream;
  Stream<void> get onReset => _resetController.stream;
  Stream<void> get onFontSizeIncrease => _fontSizeIncreaseController.stream;
  Stream<void> get onFontSizeDecrease => _fontSizeDecreaseController.stream;
  Stream<void> get onMirrorToggle => _mirrorToggleController.stream;
  Stream<bool> get onClientConnectionChange =>
      _clientConnectedController.stream;
  Stream<String> get onDocumentSelected => _documentSelectedController.stream;
  Stream<void> get onControlExit => _controlExitController.stream;
  Stream<void> get onFinishTake => _finishTakeController.stream;

  /// Scripts were created or edited from the web; the app should reload them.
  Stream<void> get onDocumentsChanged => _documentsChangedController.stream;

  /// Take state for the web remote: status, open script, stats, last result.
  Map<String, Object?> get live => liveSource?.call() ?? const {};

  // Getters
  bool get hasActiveClient => _hasActiveClient;
  String? get selectedDocumentId => _selectedDocumentId;
  int get currentWordIndex => _currentWordIndex;
  bool get isActive => _isActive;
  bool get isMirrored => _isMirrored;
  double get fontSize => _fontSize;
  double get screenWidth => _screenWidth;
  double get screenHeight => _screenHeight;
  int get fillerCount => _fillerCount;
  double get wordsPerMinute => _wordsPerMinute;
  int get elapsedSeconds => _elapsedSeconds;

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

  void updateTeleprompterState(
    int wordIndex,
    bool active, {
    double? fontSize,
    bool? isMirrored,
    double? screenWidth,
    double? screenHeight,
    int? fillerCount,
    double? wordsPerMinute,
    int? elapsedSeconds,
  }) {
    _currentWordIndex = wordIndex;
    if (fillerCount != null) _fillerCount = fillerCount;
    if (wordsPerMinute != null) _wordsPerMinute = wordsPerMinute;
    if (elapsedSeconds != null) _elapsedSeconds = elapsedSeconds;
    _isActive = active;
    if (fontSize != null) _fontSize = fontSize;
    if (isMirrored != null) _isMirrored = isMirrored;
    if (screenWidth != null) _screenWidth = screenWidth;
    if (screenHeight != null) _screenHeight = screenHeight;
  }

  void exitControl() {
    _controlExitController.add(null);
  }

  void finishTake() => _finishTakeController.add(null);

  void documentsChanged() => _documentsChangedController.add(null);

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
    _finishTakeController.close();
    _documentsChangedController.close();
  }
}
