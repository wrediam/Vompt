import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/teleprompter/engine/performance_analyzer.dart';

/// Things the assistant can do to a script.
enum ScriptTask {
  speakable(
    'Make it sound spoken',
    'Plainer words and sentences that are easy to say',
  ),
  tighten('Tighten', 'Cut about a fifth without losing a point'),
  fitTime('Fit to a length', 'Rewrite to run a set number of seconds'),
  grammar('Fix spelling and grammar', 'Changes as little as possible'),
  hooks('Opening lines', 'Three ways to grab attention in the first seconds'),
  draft('Draft from notes', 'Turn bullet points into a script');

  final String label;
  final String description;
  const ScriptTask(this.label, this.description);

  /// Tasks whose result replaces the script (the others are suggestions).
  bool get rewrites => this != ScriptTask.hooks;
}

class AssistantUnavailable implements Exception {
  final String message;
  const AssistantUnavailable(this.message);
  @override
  String toString() => message;
}

/// Script tools powered by Apple's on-device model (Apple Intelligence).
/// Nothing leaves the phone. The same prompts serve the app and the web remote.
class ScriptAssistant {
  ScriptAssistant._();
  static final ScriptAssistant instance = ScriptAssistant._();

  static const _methods = MethodChannel('vompt/ai');

  /// Words per minute used to turn seconds into a word budget.
  static const defaultPace = 150;

  /// Largest piece of script sent in one request. The on-device model has a
  /// small context window, so longer scripts are handled paragraph by paragraph.
  static const _chunkWords = 450;

  static const _editorVoice =
      'You edit scripts that a person reads aloud from a teleprompter, on camera '
      'or on stage. Write the way a confident person talks: plain words, '
      'contractions, active voice, and sentences that are easy to say in one '
      'breath. Vary sentence length so it flows; never write a string of '
      "three-word fragments. Keep the speaker's meaning, facts, names and "
      'numbers. Never invent facts, prices, dates or claims. Reply with the '
      'script text only: no title, no introduction, no notes, no quotation '
      'marks, no markdown.';

  static const _coachVoice =
      'You are a speaking coach. You give short, specific, encouraging advice '
      'based on data from a practice read of a teleprompter script. Plain '
      'sentences, no markdown, no headings, no numbering.';

  ({bool available, String? reason})? _availability;

  /// Whether Apple Intelligence can run here, and if not, why (user-facing).
  Future<({bool available, String? reason})> availability({
    bool refresh = false,
  }) async {
    if (_availability != null && !refresh) return _availability!;
    if (!Platform.isIOS) {
      return _availability = (
        available: false,
        reason: 'Script tools need an iPhone with Apple Intelligence.',
      );
    }
    try {
      final raw = await _methods.invokeMapMethod<String, dynamic>(
        'availability',
      );
      final available = raw?['available'] == true;
      return _availability = (
        available: available,
        reason: raw?['reason'] as String?,
      );
    } on PlatformException catch (e) {
      return (available: false, reason: e.message);
    } on MissingPluginException {
      return (
        available: false,
        reason: 'Script tools need an iPhone with Apple Intelligence.',
      );
    }
  }

  /// Runs [task] on [text]. [seconds] sets the target length for
  /// [ScriptTask.fitTime] and [ScriptTask.draft]; [tone] guides drafts.
  Future<String> run(
    ScriptTask task,
    String text, {
    int? seconds,
    int pace = defaultPace,
    String tone = 'warm and confident',
  }) async {
    final status = await availability(
      refresh: _availability?.available != true,
    );
    if (!status.available) {
      throw AssistantUnavailable(
        status.reason ?? 'Apple Intelligence is not available.',
      );
    }
    final source = text.trim();
    if (source.isEmpty) {
      throw const AssistantUnavailable('Write or paste some text first.');
    }

    switch (task) {
      case ScriptTask.hooks:
        final out = await _generate(
          _editorVoice,
          'Write 3 different opening lines for this script that hook a viewer in '
          'the first five seconds. One per line. No numbering, no quotes.\n\n'
          'Script:\n${_firstWords(source, _chunkWords)}',
          temperature: 0.8,
        );
        return out
            .split('\n')
            .map(_cleanLine)
            .where((l) => l.isNotEmpty)
            .take(3)
            .join('\n');

      case ScriptTask.draft:
        final words = ((seconds ?? 60) * pace / 60).round();
        return _clean(
          await _generate(
            _editorVoice,
            'Write a script of about $words words for someone to read on camera, '
            'from these notes. Tone: $tone. Use every note; add nothing the notes '
            "don't support.\n\nNotes:\n$source",
            temperature: 0.7,
          ),
        );

      case ScriptTask.speakable ||
          ScriptTask.tighten ||
          ScriptTask.grammar ||
          ScriptTask.fitTime:
        final total = _wordCount(source);
        final target = task == ScriptTask.fitTime
            ? ((seconds ?? 60) * pace / 60).round()
            : task == ScriptTask.tighten
            ? (total * 0.8).round()
            : total;
        final chunks = _chunks(source);
        final results = <String>[];
        for (final chunk in chunks) {
          final share = (target * _wordCount(chunk) / total).round().clamp(
            5,
            100000,
          );
          results.add(
            _clean(
              await _generate(
                _editorVoice,
                _rewritePrompt(task, chunk, share),
                temperature: task == ScriptTask.grammar ? 0.1 : 0.4,
              ),
            ),
          );
        }
        return results.join('\n\n');
    }
  }

  /// Three short tips from a take's stats, for the summary screen.
  Future<String> coach(
    PerformanceStats stats, {
    required Duration duration,
    required double wordsPerMinute,
    required List<String> scriptWords,
  }) async {
    final status = await availability();
    if (!status.available) {
      throw AssistantUnavailable(status.reason ?? 'Unavailable');
    }
    final fillers = stats.fillers.entries
        .map((e) => '${e.key} ${e.value}')
        .join(', ');
    final skipped = stats.skipped
        .take(2)
        .map(
          (r) =>
              '"${scriptWords.sublist(r.firstWord, r.lastWord + 1).join(' ')}"',
        )
        .join('; ');
    final m = duration.inMinutes,
        s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final out = await _generate(
      _coachVoice,
      'Practice read results:\n'
      '- Duration $m:$s, pace ${wordsPerMinute.round()} words per minute '
      '(comfortable for video is 140 to 160)\n'
      '- Fillers: ${fillers.isEmpty ? 'none' : fillers}\n'
      '- Skipped: ${skipped.isEmpty ? 'nothing' : skipped}\n'
      '- Restarts: ${stats.repeats}\n'
      '- Pauses over 2 seconds: ${stats.longPauses}\n\n'
      'Give exactly three tips, one per line, each under 25 words. Refer to the '
      'actual numbers. If something went well, say so in one of the tips.',
      temperature: 0.5,
    );
    return out
        .split('\n')
        .map(_cleanLine)
        .where((l) => l.isNotEmpty)
        .take(3)
        .join('\n');
  }

  String _rewritePrompt(ScriptTask task, String chunk, int words) {
    final now = _wordCount(chunk);
    switch (task) {
      case ScriptTask.speakable:
        return 'Rewrite this script so it sounds natural spoken aloud. Keep every '
            'point and about the same length.\n\nScript:\n$chunk';
      case ScriptTask.tighten:
        return 'Cut this script to about $words words. It is $now words now. Remove '
            'repetition and filler; keep every key point and number.\n\nScript:\n$chunk';
      case ScriptTask.fitTime:
        return words >= now
            ? 'Rewrite this script to about $words words. It is $now words now. '
                  "Expand only what's already there, with no new facts.\n\nScript:\n$chunk"
            : 'Cut this script to about $words words. It is $now words now. Keep the '
                  'most important points and every number you keep exact.\n\nScript:\n$chunk';
      case ScriptTask.grammar:
        return 'Fix spelling, grammar, capitalization and punctuation in this script. '
            'Change as little as possible.\n\nScript:\n$chunk';
      default:
        return chunk;
    }
  }

  Future<String> _generate(
    String instructions,
    String prompt, {
    double? temperature,
  }) async {
    try {
      final out = await _methods.invokeMethod<String>('generate', {
        'instructions': instructions,
        'prompt': prompt,
        'temperature': ?temperature,
      });
      return out ?? '';
    } on PlatformException catch (e) {
      throw AssistantUnavailable(
        e.message ?? 'Apple Intelligence could not finish.',
      );
    }
  }

  /// Splits on paragraphs, packing them into pieces of at most [_chunkWords].
  static List<String> _chunks(String text) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty);
    final chunks = <String>[];
    final current = StringBuffer();
    var count = 0;
    for (final p in paragraphs) {
      final n = _wordCount(p);
      if (count > 0 && count + n > _chunkWords) {
        chunks.add(current.toString().trim());
        current.clear();
        count = 0;
      }
      current.writeln(p.trim());
      current.writeln();
      count += n;
    }
    if (count > 0) chunks.add(current.toString().trim());
    return chunks;
  }

  static int _wordCount(String s) =>
      s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

  static String _firstWords(String s, int n) {
    final words = s.trim().split(RegExp(r'\s+'));
    return words.length <= n ? s : words.take(n).join(' ');
  }

  /// Removes the chatter models sometimes wrap around an answer.
  @visibleForTesting
  static String cleanForTest(String s) => _clean(s);

  static String _clean(String raw) {
    var s = raw
        .trim()
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    s = s.replaceFirst(
      RegExp(
        r"^(sure[,!.]?\s*)?(here(’|')?s|here is|below is)[^\n]*:\s*\n+",
        caseSensitive: false,
      ),
      '',
    );
    if (s.length > 1 &&
        (s.startsWith('"') && s.endsWith('"') ||
            s.startsWith('“') && s.endsWith('”'))) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  static String _cleanLine(String line) => _clean(line)
      .replaceFirst(RegExp(r'^\s*([-*•]|\d+[.)])\s*'), '')
      .replaceAll(RegExp(r'^["“]|["”]$'), '')
      .trim();
}
