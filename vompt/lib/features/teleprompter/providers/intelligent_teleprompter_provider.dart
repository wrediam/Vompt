import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/document.dart';
import '../../../data/models/practice_session.dart';
import '../../../data/repositories/practice_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../services/remote_control_service.dart';
import '../engine/performance_analyzer.dart';
import '../engine/script_document.dart';
import '../engine/script_tracker.dart';
import '../engine/transcript_assembler.dart';
import '../services/speech_input.dart';

enum PrompterStatus { idle, preparing, listening, paused, finished }

/// Drives the teleprompter: follows the reader with [ScriptTracker], scores
/// the take with [PerformanceAnalyzer], and saves it when the take finishes.
class IntelligentTeleprompterProvider with ChangeNotifier {
  IntelligentTeleprompterProvider() {
    // Listen for remote commands before any script loads so none are lost.
    _initializeRemoteControl();
    _remoteControlService.liveSource = _liveState;
    _speechSub = _speech.events.listen(_onSpeech);
    _levelSub = _speech.levels.listen(_onLevel);
    _modelSub = _speech.modelProgress.listen((p) {
      _modelProgress = p < 1 ? p : null;
      notifyListeners();
    });
    _interruptSub = _speech.interruptions.listen((interrupted) {
      _interrupted = interrupted;
      notifyListeners();
    });
  }

  final SpeechInput _speech = SpeechInput();
  final RemoteControlService _remoteControlService = RemoteControlService();
  final SettingsRepository _settingsRepository = SettingsRepository();
  final PracticeRepository _practiceRepository = PracticeRepository();
  final List<StreamSubscription<dynamic>> _remoteSubs = [];
  StreamSubscription<SpeechEvent>? _speechSub;
  StreamSubscription<double>? _levelSub;
  StreamSubscription<double>? _modelSub;
  StreamSubscription<bool>? _interruptSub;

  Document? _document;
  String _scriptContent = '';
  ScriptDocument _script = ScriptDocument('');
  late ScriptTracker _tracker = ScriptTracker(_script);
  PerformanceAnalyzer _analyzer = PerformanceAnalyzer(ScriptDocument(''));
  final TranscriptAssembler _trackTranscript = TranscriptAssembler();
  List<int> _newlinesBefore = const [];

  PrompterStatus _status = PrompterStatus.idle;
  String? _error;
  bool _errorNeedsSettings = false;
  double? _modelProgress;
  bool _interrupted = false;
  final Stopwatch _clock = Stopwatch();
  Duration _stagedElapsed = Duration.zero;
  bool _staged = false;
  int _takeStartWord = 0;
  int _furthestWord = -1;
  PerformanceStats _stats = PerformanceStats.empty;
  PracticeSession? _lastSession;
  Timer? _autoFinish;
  Future<void>? _preparing;

  /// Smoothed input level in dBFS, for the mic meter.
  final ValueNotifier<double> level = ValueNotifier(-60);

  double _fontSize = 32.0;
  bool _isMirrored = false;
  bool _showStats = true;
  bool _centerText = true;
  double _screenWidth = 0.0;
  double _screenHeight = 0.0;

  // --- Getters ---------------------------------------------------------

  Document? get document => _document;
  String get scriptContent => _scriptContent;
  List<String> get scriptWords => _script.words;

  /// Line breaks before each word (0 = space, 1 = new line, 2+ = paragraph).
  List<int> get newlinesBefore => _newlinesBefore;
  int get currentWordIndex => _tracker.currentWordIndex;
  PrompterStatus get status => _status;
  bool get isSpeechActive => _status == PrompterStatus.listening;
  bool get isPreparing => _status == PrompterStatus.preparing;
  bool get hasTake =>
      _status == PrompterStatus.listening || _status == PrompterStatus.paused;
  String? get error => _error;
  bool get errorNeedsSettings => _errorNeedsSettings;

  /// Speech model download progress while it downloads, otherwise null.
  double? get modelProgress => _modelProgress;
  bool get isInterrupted => _interrupted;
  bool get countsVocalFillers => _speech.keepsFillers || _staged;
  Duration get elapsed => _clock.elapsed + _stagedElapsed;
  PerformanceStats get stats => _stats;
  PracticeSession? get lastSession => _lastSession;
  double get fontSize => _fontSize;
  bool get isMirrored => _isMirrored;
  bool get showStats => _showStats;
  bool get centerText => _centerText;
  RemoteControlService get remoteControlService => _remoteControlService;

  double get progress {
    final total = _script.words.length;
    if (total == 0 || currentWordIndex < 0) return 0;
    return ((currentWordIndex + 1) / total).clamp(0.0, 1.0);
  }

  /// Live pace: from recognized speech once there is enough, else from
  /// progress through the script.
  double get wordsPerMinute {
    if (_stats.speakingSeconds >= 10) return _stats.wordsPerMinute;
    final seconds = _clock.elapsed.inMilliseconds / 1000;
    if (seconds < 5 || currentWordIndex < _takeStartWord) return 0;
    return (currentWordIndex - _takeStartWord + 1) / seconds * 60;
  }

  // --- Script ------------------------------------------------------------

  void loadScript(Document document) {
    _cancelTake();
    _document = document;
    _scriptContent = document.content;
    _script = ScriptDocument(document.content);
    _tracker = ScriptTracker(_script);
    _analyzer = PerformanceAnalyzer(_script);
    _newlinesBefore = _computeNewlines(document.content);
    _status = PrompterStatus.idle;
    _stats = PerformanceStats.empty;
    _lastSession = null;
    _error = null;
    _clock.reset();
    _stagedElapsed = Duration.zero;

    if (_remoteControlService.hasActiveClient) _isMirrored = true;
    _loadSettings();
    _syncRemoteState();
    notifyListeners();
  }

  static List<int> _computeNewlines(String content) {
    final out = <int>[];
    var last = 0;
    for (final m in RegExp(r'\S+').allMatches(content)) {
      final gap = content.substring(last, m.start);
      out.add(out.isEmpty ? 0 : '\n'.allMatches(gap).length);
      last = m.end;
    }
    return out;
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsRepository.getSettings();
      _fontSize = settings.fontSize.clamp(16.0, 72.0);
      _showStats = settings.showStats;
      _centerText = settings.centerText;
      if (!_remoteControlService.hasActiveClient) {
        _isMirrored = settings.mirrorMode;
      }
      _syncRemoteState();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load teleprompter settings: $e');
    }
  }

  // --- Listening ---------------------------------------------------------

  /// Warms up the microphone permission and speech model so the first tap on
  /// the mic starts instantly. Errors surface when listening starts.
  Future<void> prepare() =>
      _preparing ??= _speech.prepare().catchError((Object e) {
        _preparing = null;
      });

  Future<bool> startSpeechRecognition() async {
    if (_status == PrompterStatus.listening ||
        _status == PrompterStatus.preparing) {
      return true;
    }
    if (_script.isEmpty) {
      _setError('This script is empty. Add some text in the editor first.');
      return false;
    }
    final newTake = !hasTake;
    _status = PrompterStatus.preparing;
    _error = null;
    _syncRemoteState();
    notifyListeners();

    try {
      if (_preparing != null) await _preparing;
      await _speech.prepare();
      await _speech.start(vocabulary: _vocabulary());
    } on SpeechInputException catch (e) {
      _status = newTake ? PrompterStatus.idle : PrompterStatus.paused;
      _setError(e.message, needsSettings: e.permissionDenied);
      return false;
    } catch (e) {
      _status = newTake ? PrompterStatus.idle : PrompterStatus.paused;
      _setError('Could not start listening: $e');
      return false;
    }

    if (newTake) {
      if (_tracker.isAtEnd) _tracker.reset();
      _takeStartWord = currentWordIndex + 1;
      _furthestWord = currentWordIndex;
      _analyzer = PerformanceAnalyzer(_script, startUnit: _tracker.position);
      _stats = PerformanceStats.empty;
      _lastSession = null;
      _clock.reset();
      _stagedElapsed = Duration.zero;
      _stagedElapsed = Duration.zero;
    }
    _tracker.beginTranscript();
    _trackTranscript.clear();
    _analyzer.beginSession();
    _clock.start();
    _status = PrompterStatus.listening;
    _interrupted = false;
    _syncRemoteState();
    notifyListeners();
    return true;
  }

  /// Pauses the take; listening can resume where it left off.
  Future<void> stopSpeechRecognition() async {
    if (_status != PrompterStatus.listening) return;
    _autoFinish?.cancel();
    _status = PrompterStatus.paused;
    _clock.stop();
    level.value = -60;
    notifyListeners();
    await _speech.stop();
    _stats = _analyzer.stats;
    _syncRemoteState();
    notifyListeners();
  }

  Future<void> toggleListening() =>
      isSpeechActive ? stopSpeechRecognition() : startSpeechRecognition();

  /// Ends the take, scores it, saves it, and shows the summary.
  Future<void> finishTake() async {
    if (!hasTake) return;
    _autoFinish?.cancel();
    if (_status == PrompterStatus.listening) {
      _status = PrompterStatus.paused;
      notifyListeners();
      await _speech.stop();
    }
    _clock.stop();
    level.value = -60;
    _stats = _analyzer.stats;
    _status = PrompterStatus.finished;

    final doc = _document;
    final total = _script.words.length - _takeStartWord;
    final session = PracticeSession(
      id: const Uuid().v4(),
      documentId: doc?.id ?? '',
      createdAt: DateTime.now(),
      durationSeconds: _clock.elapsed.inMilliseconds / 1000,
      wordsPerMinute: wordsPerMinute,
      fillers: _stats.fillers,
      skippedWords: _stats.skippedWords,
      misreads: _stats.misreads.length,
      repeats: _stats.repeats,
      longPauses: _stats.longPauses,
      accuracy: _stats.accuracy,
      completion: total <= 0
          ? 1
          : ((_furthestWord - _takeStartWord + 1) / total).clamp(0.0, 1.0),
    );
    _lastSession = session;
    _syncRemoteState();
    notifyListeners();

    // Takes shorter than a few seconds are accidental taps, not practice.
    if (doc != null && session.durationSeconds >= 5) {
      try {
        await _practiceRepository.save(session);
      } catch (e) {
        debugPrint('Failed to save practice take: $e');
      }
    }
  }

  /// Back to the top for a fresh take.
  void reset() {
    _cancelTake();
    _tracker.reset();
    _status = PrompterStatus.idle;
    _stats = PerformanceStats.empty;
    _clock.reset();
    _stagedElapsed = Duration.zero;
    _error = null;
    _syncRemoteState();
    notifyListeners();
  }

  /// Continue reading from [wordIndex] (e.g. after a long-press on a word).
  void jumpToWord(int wordIndex) {
    _autoFinish?.cancel();
    _tracker.jumpToWord(wordIndex.clamp(0, _script.words.length));
    if (!hasTake) _status = PrompterStatus.idle;
    _syncRemoteState();
    notifyListeners();
  }

  void dismissError() {
    _error = null;
    notifyListeners();
  }

  void _cancelTake() {
    _autoFinish?.cancel();
    if (_status == PrompterStatus.listening ||
        _status == PrompterStatus.preparing) {
      _speech.stop();
    }
    _clock.stop();
    level.value = -60;
  }

  void _setError(String message, {bool needsSettings = false}) {
    _error = message;
    _errorNeedsSettings = needsSettings;
    _syncRemoteState();
    notifyListeners();
  }

  /// Script words worth biasing recognition toward: names and longer words.
  List<String> _vocabulary() {
    final seen = <String>{};
    for (final raw in _script.words) {
      final word = raw.replaceAll(
        RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
        '',
      );
      if (word.length >= 6 ||
          (word.length >= 3 && word[0] != word[0].toLowerCase())) {
        seen.add(word);
      }
      if (seen.length >= 100) break;
    }
    return seen.toList();
  }

  void _onSpeech(SpeechEvent event) {
    if (_status != PrompterStatus.listening &&
        _status != PrompterStatus.paused) {
      return;
    }

    if (event.channel == _speech.trackChannel) {
      final tokens = _script.normalizeSpeech(event.text);
      if (event.isFinal) {
        _trackTranscript.addFinal(tokens);
      } else {
        _trackTranscript.setVolatile(tokens);
      }
      if (_tracker.update(_trackTranscript.tokens)) _onPositionChanged();
    }

    if (event.channel == SpeechChannel.full && event.isFinal) {
      final words = event.words.isNotEmpty
          ? event.words
          : [
              for (final w in event.text.split(RegExp(r'\s+')))
                if (w.isNotEmpty) SpokenWord(w, 0, 0),
            ];
      _analyzer.addUtterance(words, anchorUnit: _tracker.position);
      _stats = _analyzer.stats;
      _syncRemoteState();
      notifyListeners();
    }
  }

  void _onPositionChanged() {
    if (currentWordIndex > _furthestWord) _furthestWord = currentWordIndex;
    _syncRemoteState();
    notifyListeners();

    // Reaching the last word and then going quiet ends the take.
    _autoFinish?.cancel();
    if (_tracker.isAtEnd && _status == PrompterStatus.listening) {
      _autoFinish = Timer(const Duration(milliseconds: 2500), finishTake);
    }
  }

  void _onLevel(double db) {
    if (_status != PrompterStatus.listening) return;
    // Fast attack, slow release, so the meter reads as speech, not flicker.
    final current = level.value;
    level.value = db > current
        ? db
        : current - 4 < db
        ? db
        : current - 4;
  }

  /// Puts the prompter in a fixed state for App Store screenshots
  /// (see showcase.dart). Never used in normal operation.
  void showcase({
    required int word,
    required PrompterStatus status,
    required Duration elapsed,
    required PerformanceStats stats,
  }) {
    _tracker.jumpToWord(word + 1);
    _staged = true;
    _status = status;
    _stats = stats;
    _stagedElapsed = elapsed;
    _takeStartWord = 0;
    level.value = -24;
    if (status == PrompterStatus.finished) {
      _lastSession = PracticeSession(
        id: 'showcase',
        documentId: _document?.id ?? '',
        createdAt: DateTime.now(),
        durationSeconds: elapsed.inMilliseconds / 1000,
        wordsPerMinute: stats.wordsPerMinute,
        fillers: stats.fillers,
        skippedWords: stats.skippedWords,
        misreads: stats.misreads.length,
        repeats: stats.repeats,
        longPauses: stats.longPauses,
        accuracy: stats.accuracy,
        completion: 1,
      );
    }
    notifyListeners();
  }

  // --- Display settings --------------------------------------------------

  void setFontSize(double size) {
    _fontSize = size.clamp(16.0, 72.0);
    _syncRemoteState();
    _settingsRepository.updateFontSize(_fontSize);
    notifyListeners();
  }

  void increaseFontSize() => setFontSize(_fontSize + 2);
  void decreaseFontSize() => setFontSize(_fontSize - 2);

  void toggleMirror() {
    _isMirrored = !_isMirrored;
    _settingsRepository.updateMirrorMode(_isMirrored);
    _syncRemoteState();
    notifyListeners();
  }

  void toggleStats() {
    _showStats = !_showStats;
    _settingsRepository.updateShowStats(_showStats);
    notifyListeners();
  }

  void toggleCenterText() {
    _centerText = !_centerText;
    _settingsRepository.updateCenterText(_centerText);
    notifyListeners();
  }

  void updateScreenDimensions(double width, double height) {
    _screenWidth = width;
    _screenHeight = height;
    _syncRemoteState();
  }

  // --- Remote control ----------------------------------------------------

  void _initializeRemoteControl() {
    for (final sub in _remoteSubs) {
      sub.cancel();
    }
    _remoteSubs
      ..clear()
      ..add(
        _remoteControlService.onStartSpeech.listen(
          (_) => startSpeechRecognition(),
        ),
      )
      ..add(
        _remoteControlService.onStopSpeech.listen(
          (_) => stopSpeechRecognition(),
        ),
      )
      ..add(_remoteControlService.onReset.listen((_) => reset()))
      ..add(
        _remoteControlService.onFontSizeIncrease.listen(
          (_) => increaseFontSize(),
        ),
      )
      ..add(
        _remoteControlService.onFontSizeDecrease.listen(
          (_) => decreaseFontSize(),
        ),
      )
      ..add(_remoteControlService.onMirrorToggle.listen((_) => toggleMirror()))
      ..add(_remoteControlService.onFinishTake.listen((_) => finishTake()));
  }

  void _syncRemoteState() {
    _remoteControlService.updateTeleprompterState(
      currentWordIndex,
      isSpeechActive,
      fontSize: _fontSize,
      isMirrored: _isMirrored,
      screenWidth: _screenWidth > 0 ? _screenWidth : null,
      screenHeight: _screenHeight > 0 ? _screenHeight : null,
      fillerCount: _stats.fillerCount,
      wordsPerMinute: wordsPerMinute,
      elapsedSeconds: _clock.elapsed.inSeconds,
    );
  }

  Map<String, Object?> _liveState() {
    final session = _lastSession;
    return {
      'status': _status.name,
      'documentId': _document?.id,
      'title': _document?.title,
      'error': _error,
      'progress': progress,
      'elapsedSeconds': _clock.elapsed.inMilliseconds / 1000,
      'wordsPerMinute': wordsPerMinute,
      'fillers': _stats.fillers,
      'modelProgress': _modelProgress,
      'lastTake': session == null
          ? null
          : {
              'durationSeconds': session.durationSeconds,
              'wordsPerMinute': session.wordsPerMinute,
              'fillers': session.fillers,
              'skippedWords': session.skippedWords,
              'skipped': [
                for (final r in _stats.skipped.take(5))
                  _script.words.sublist(r.firstWord, r.lastWord + 1).join(' '),
              ],
              'misreads': [
                for (final m in _stats.misreads.take(8))
                  {'said': m.said, 'expected': m.expected},
              ],
              'repeats': session.repeats,
              'longPauses': session.longPauses,
              'accuracy': session.accuracy,
            },
    };
  }

  @override
  void dispose() {
    for (final sub in _remoteSubs) {
      sub.cancel();
    }
    _speechSub?.cancel();
    _levelSub?.cancel();
    _modelSub?.cancel();
    _interruptSub?.cancel();
    _autoFinish?.cancel();
    _speech.dispose();
    level.dispose();
    super.dispose();
  }
}
