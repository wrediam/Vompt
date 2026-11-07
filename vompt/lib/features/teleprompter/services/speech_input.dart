import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../engine/performance_analyzer.dart';

/// Which job a transcript is for: following the reader, or scoring the take.
enum SpeechChannel { track, full }

/// One update from the recognizer. Volatile updates replace the previous
/// volatile text of the same channel; final ones are permanent.
class SpeechEvent {
  final SpeechChannel channel;
  final bool isFinal;
  final String text;
  final List<SpokenWord> words;
  const SpeechEvent(this.channel, this.isFinal, this.text, this.words);
}

class SpeechInputException implements Exception {
  final String message;
  final bool permissionDenied;
  const SpeechInputException(this.message, {this.permissionDenied = false});
  @override
  String toString() => message;
}

/// Live speech recognition for the teleprompter.
///
/// On iOS 26+ this uses the app's native SpeechAnalyzer engine, which keeps
/// "um"/"uh" and never stops between sentences. Otherwise it falls back to
/// the speech_to_text plugin, restarting it whenever iOS ends a session.
class SpeechInput {
  static const _methods = MethodChannel('vompt/speech');
  static const _eventChannel = EventChannel('vompt/speech/events');

  final _events = StreamController<SpeechEvent>.broadcast();
  final _levels = StreamController<double>.broadcast();
  final _modelProgress = StreamController<double>.broadcast();
  final _interruptions = StreamController<bool>.broadcast();
  StreamSubscription<dynamic>? _nativeSub;

  bool? _nativeSupported;
  bool _usingNative = false;
  SpeechChannel _trackChannel = SpeechChannel.track;

  final SpeechToText _legacy = SpeechToText();
  bool _legacyReady = false;
  bool _legacyWanted = false;
  Timer? _legacyRestart;

  Stream<SpeechEvent> get events => _events.stream;

  /// Input loudness in dBFS, about ten times a second while listening.
  Stream<double> get levels => _levels.stream;

  /// Speech model download progress (0..1), first run only.
  Stream<double> get modelProgress => _modelProgress.stream;

  /// true when audio was interrupted (call, Siri), false when it resumed.
  Stream<bool> get interruptions => _interruptions.stream;

  /// Whether the transcript keeps vocal fillers like "um" and "uh".
  bool get keepsFillers => _usingNative;

  /// Which channel to follow the reader with.
  SpeechChannel get trackChannel => _trackChannel;

  Future<bool> _isNativeSupported() async {
    if (_nativeSupported != null) return _nativeSupported!;
    if (!Platform.isIOS) return _nativeSupported = false;
    try {
      _nativeSupported =
          await _methods.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Speech: native engine unavailable: ${e.message}');
      _nativeSupported = false;
    } on MissingPluginException {
      _nativeSupported = false;
    }
    return _nativeSupported!;
  }

  /// Asks for the microphone and gets the speech model ready. Safe to call
  /// repeatedly; the model download only happens once.
  Future<void> prepare() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw const SpeechInputException(
        'Vompt needs the microphone to follow your reading.',
        permissionDenied: true,
      );
    }
    if (await _isNativeSupported()) {
      _listenNative();
      try {
        await _methods.invokeMethod<String>('prepare', {'locale': _localeId()});
        return;
      } on PlatformException catch (e) {
        debugPrint(
          'Speech: native prepare failed, using fallback: ${e.message}',
        );
        _nativeSupported = false;
      }
    }
    await _prepareLegacy();
  }

  /// Starts listening. [vocabulary] biases recognition toward script words.
  Future<void> start({List<String> vocabulary = const []}) async {
    if (await _isNativeSupported()) {
      _listenNative();
      try {
        final channel = await _methods.invokeMethod<String>('start', {
          'locale': _localeId(),
          'contextualStrings': vocabulary,
        });
        _usingNative = true;
        _trackChannel = channel == 'full'
            ? SpeechChannel.full
            : SpeechChannel.track;
        return;
      } on PlatformException catch (e) {
        debugPrint('Speech: native start failed, using fallback: ${e.message}');
        _nativeSupported = false;
      }
    }
    _usingNative = false;
    _trackChannel = SpeechChannel.track;
    await _startLegacy();
  }

  /// Stops listening. Final words are delivered before this completes.
  Future<void> stop() async {
    if (_usingNative) {
      try {
        await _methods.invokeMethod<void>('stop');
      } on PlatformException catch (e) {
        debugPrint('Speech: native stop failed: ${e.message}');
      }
      // Let events queued behind the reply drain into listeners.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } else {
      await _stopLegacy();
    }
  }

  void dispose() {
    _nativeSub?.cancel();
    _legacyRestart?.cancel();
    _legacyWanted = false;
    if (_legacy.isListening) _legacy.cancel();
    _events.close();
    _levels.close();
    _modelProgress.close();
    _interruptions.close();
  }

  String _localeId() {
    final locale = PlatformDispatcher.instance.locale;
    final country = locale.countryCode;
    return country == null || country.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_$country';
  }

  void _listenNative() {
    _nativeSub ??= _eventChannel.receiveBroadcastStream().listen((raw) {
      if (raw is! Map) return;
      switch (raw['type']) {
        case 'volatile' || 'final':
          final words = <SpokenWord>[
            for (final w in (raw['words'] as List? ?? const []))
              if (w is Map)
                SpokenWord(
                  w['w'] as String? ?? '',
                  (w['s'] as num? ?? 0).toDouble(),
                  (w['e'] as num? ?? 0).toDouble(),
                ),
          ];
          _events.add(
            SpeechEvent(
              raw['channel'] == 'full'
                  ? SpeechChannel.full
                  : SpeechChannel.track,
              raw['type'] == 'final',
              raw['text'] as String? ?? '',
              words,
            ),
          );
        case 'level':
          _levels.add((raw['db'] as num).toDouble());
        case 'model':
          _modelProgress.add((raw['progress'] as num).toDouble());
        case 'interrupted':
          _interruptions.add(true);
        case 'resumed':
          _interruptions.add(false);
        case 'error':
          debugPrint('Speech: ${raw['message']}');
      }
    }, onError: (Object e) => debugPrint('Speech event error: $e'));
  }

  // --- speech_to_text fallback -------------------------------------------

  Future<void> _prepareLegacy() async {
    if (_legacyReady) return;
    _legacyReady = await _legacy
        .initialize(
          onError: (error) {
            debugPrint('Speech (fallback) error: ${error.errorMsg}');
            if (_legacyWanted && error.errorMsg != 'error_permission') {
              _scheduleLegacyRestart();
            }
          },
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') &&
                _legacyWanted) {
              _scheduleLegacyRestart();
            }
          },
        )
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
    if (!_legacyReady) {
      throw const SpeechInputException(
        'Speech recognition is not available. Check that Siri & Dictation are '
        'enabled and that Vompt is allowed to use Speech Recognition in Settings.',
        permissionDenied: true,
      );
    }
  }

  Future<void> _startLegacy() async {
    await _prepareLegacy();
    _legacyWanted = true;
    await _listenLegacy();
  }

  Future<void> _listenLegacy() async {
    if (!_legacyWanted) return;
    if (_legacy.isListening) await _legacy.stop();
    try {
      await _legacy.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          if (text.isEmpty) return;
          _events.add(
            SpeechEvent(
              SpeechChannel.track,
              result.finalResult,
              text,
              const [],
            ),
          );
          if (result.finalResult) {
            _events.add(SpeechEvent(SpeechChannel.full, true, text, const []));
          }
        },
        onSoundLevelChange: (level) => _levels.add(level),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          onDevice: true,
        ),
      );
    } catch (e) {
      debugPrint('Speech (fallback) listen failed: $e');
      _scheduleLegacyRestart();
    }
  }

  void _scheduleLegacyRestart() {
    _legacyRestart?.cancel();
    _legacyRestart = Timer(const Duration(milliseconds: 50), _listenLegacy);
  }

  Future<void> _stopLegacy() async {
    _legacyWanted = false;
    _legacyRestart?.cancel();
    if (_legacy.isListening) await _legacy.stop();
  }
}
