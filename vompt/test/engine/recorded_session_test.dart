import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vompt/features/teleprompter/engine/performance_analyzer.dart';
import 'package:vompt/features/teleprompter/engine/script_document.dart';
import 'package:vompt/features/teleprompter/engine/script_tracker.dart';
import 'package:vompt/features/teleprompter/engine/transcript_assembler.dart';

/// Replays real SpeechAnalyzer output recorded on macOS from synthesized
/// speech (see test/fixtures). "track" is the low-latency dictation stream
/// that drives the highlight; "full" keeps fillers and feeds the stats.
class _Replay {
  final ScriptDocument doc;
  final ScriptTracker tracker;
  final PerformanceAnalyzer analyzer;
  final List<int> positions = [];
  final List<String> fullText = [];

  _Replay(String name)
    : doc = ScriptDocument(
        File('test/fixtures/script${name[0]}.txt').readAsStringSync(),
      ),
      tracker = ScriptTracker(
        ScriptDocument(
          File('test/fixtures/script${name[0]}.txt').readAsStringSync(),
        ),
      ),
      analyzer = PerformanceAnalyzer(
        ScriptDocument(
          File('test/fixtures/script${name[0]}.txt').readAsStringSync(),
        ),
      ) {
    final track = _load('test/fixtures/perf${name}_track.jsonl', 'track');
    final full = _load('test/fixtures/perf${name}_full.jsonl', 'full');
    final events = [...track, ...full]
      ..sort((a, b) => (a['t'] as num).compareTo(b['t'] as num));
    final transcript = TranscriptAssembler();
    for (final e in events) {
      final isFinal = e['type'] == 'final';
      if (e['channel'] == 'track') {
        final tokens = tracker.script.normalizeSpeech(e['text'] as String);
        isFinal ? transcript.addFinal(tokens) : transcript.setVolatile(tokens);
        tracker.update(transcript.tokens);
        positions.add(tracker.currentWordIndex);
      } else if (isFinal) {
        fullText.add(e['text'] as String);
        final words = [
          for (final w in e['words'] as List)
            SpokenWord(
              w['w'] as String,
              ((w['s'] ?? (w['e'] as num) - 0.3) as num).toDouble(),
              (w['e'] as num).toDouble(),
            ),
        ];
        analyzer.addUtterance(words, anchorUnit: tracker.position);
      }
    }
  }

  static List<Map<String, dynamic>> _load(String path, String channel) => [
    for (final line in File(path).readAsLinesSync())
      if (line.trim().isNotEmpty)
        {...jsonDecode(line) as Map<String, dynamic>, 'channel': channel},
  ];

  int wordIndex(String phrase) {
    final target = phrase.split(' ');
    for (var i = 0; i + target.length <= doc.words.length; i++) {
      var ok = true;
      for (var k = 0; k < target.length; k++) {
        final w = doc.words[i + k].toLowerCase().replaceAll(
          RegExp(r'[^\w%]'),
          '',
        );
        if (w != target[k]) {
          ok = false;
          break;
        }
      }
      if (ok) return i + target.length - 1;
    }
    throw StateError('"$phrase" not in script');
  }

  String wordsIn(SkippedRange r) =>
      doc.words.sublist(r.firstWord, r.lastWord + 1).join(' ');
}

void main() {
  group('morning routine take (fillers, repeat, skip, ad-lib)', () {
    late _Replay r;
    setUpAll(() => r = _Replay('1'));

    test('ends on the last word of the script', () {
      expect(r.tracker.currentWordIndex, r.doc.words.length - 1);
    });

    test('highlight never runs ahead of the reader by a sentence', () {
      // The skipped sentence starts at "once"; the highlight may only pass
      // it after the reader is into "the key is".
      final skipStart = r.wordIndex('once that feels');
      final skipEnd = r.wordIndex('walk outside');
      final inSkip = r.positions.where((p) => p > skipStart && p <= skipEnd);
      expect(inSkip, isEmpty, reason: 'highlight entered the skipped sentence');
    });

    test('counts fillers, the repeat and the skipped sentence', () {
      final s = r.analyzer.stats;
      expect(s.fillers['um'], 1, reason: 'full transcript: ${r.fullText}');
      expect(s.fillers['ah'], 1);
      expect(s.fillers['like'], 1);
      expect(s.fillers['you know'], 1);
      expect(s.repeats, 1, reason: '"drink a glass of" was said twice');
      expect(
        s.skipped.map(r.wordsIn),
        contains(
          'Once that feels automatic, add a second habit, like a five-minute walk outside.',
        ),
      );
      // The take also says "tells" for "signals to"; small slips like that
      // may show up as one- or two-word gaps, never as long ones.
      expect(s.skipped.where((g) => g.length > 2), hasLength(1));
      expect(s.extraWords.join(' '), contains('by the way'));
      expect(s.longPauses, 1, reason: '2.5 s silence before "The key"');
      expect(s.accuracy, greaterThan(0.85));
      expect(s.wordsPerMinute, inInclusiveRange(120, 220));
    });
  });

  group(
    'quarterly update take (ad-lib, skip ahead, go back, jump forward)',
    () {
      late _Replay r;
      setUpAll(() => r = _Replay('2'));

      test('ends on the last word of the script', () {
        expect(r.tracker.currentWordIndex, r.doc.words.length - 1);
      });

      test('follows the reader back to the sentence they skipped', () {
        final second = r.wordIndex('most requested feature');
        final changes = r.wordIndex('impact on our numbers');
        // After reaching "...our numbers" early, the highlight must come back
        // to "most requested feature" when the reader backs up.
        final reachedChanges = r.positions.indexWhere((p) => p >= changes);
        expect(reachedChanges, isNonNegative);
        final cameBack = r.positions
            .skip(reachedChanges)
            .any((p) => p >= second - 2 && p <= second + 2);
        expect(cameBack, isTrue, reason: 'positions: ${r.positions}');
      });

      test('reports the sentence that was never read', () {
        final s = r.analyzer.stats;
        expect(
          s.skipped.map(r.wordsIn).join(' | '),
          contains('Weekly active users grew by 18%'),
        );
        expect(s.skipped.map(r.wordsIn).join(' | '), isNot(contains('Second')));
        expect(s.fillers['um'], 1, reason: 'full transcript: ${r.fullText}');
        expect(s.repeats, 0);
      });
    },
  );
}
