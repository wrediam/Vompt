import 'package:flutter_test/flutter_test.dart';
import 'package:vompt/features/teleprompter/engine/script_document.dart';
import 'package:vompt/features/teleprompter/engine/script_tracker.dart';
import 'package:vompt/features/teleprompter/engine/text_normalizer.dart';

const _script =
    'Welcome back to the channel. Today we are talking about how to build a '
    'morning routine that actually sticks. Most people try to change everything '
    'at once, and that is exactly why they fail. Instead, start with one small '
    'habit. For example, drink a glass of water as soon as you wake up. It takes '
    'ten seconds, and it signals to your brain that the day has started. Once '
    'that feels automatic, add a second habit, like a five-minute walk outside. '
    'The key is consistency, not intensity.';

/// Feeds [spoken] one word at a time, the way live partial results grow.
ScriptTracker _speak(String spoken, {ScriptTracker? tracker}) {
  final doc = tracker?.script ?? ScriptDocument(_script);
  final t = tracker ?? ScriptTracker(doc);
  final words = spoken.split(' ');
  for (var i = 1; i <= words.length; i++) {
    t.update(doc.normalizeSpeech(words.take(i).join(' ')));
  }
  return t;
}

int _wordIndexOf(ScriptDocument doc, String word, {int occurrence = 1}) {
  var seen = 0;
  for (var i = 0; i < doc.words.length; i++) {
    if (TextNormalizer.normalizeWord(doc.words[i]).join() == word) {
      seen++;
      if (seen == occurrence) return i;
    }
  }
  throw StateError('$word not found');
}

void main() {
  late ScriptDocument doc;
  setUp(() => doc = ScriptDocument(_script));

  test('starts with nothing highlighted', () {
    expect(ScriptTracker(doc).currentWordIndex, -1);
  });

  test('follows a straight read word by word', () {
    final t = ScriptTracker(doc);
    final words = 'welcome back to the channel today we are talking'.split(' ');
    for (var i = 0; i < words.length; i++) {
      t.update(doc.normalizeSpeech(words.take(i + 1).join(' ')));
      expect(t.currentWordIndex, i, reason: 'after "${words[i]}"');
    }
  });

  test('ignores fillers and keeps going', () {
    final t = _speak(
      'welcome back um to the uh channel like you know today we are talking',
    );
    expect(t.currentWordIndex, _wordIndexOf(doc, 'talking'));
  });

  test('holds position through an ad-lib, then continues', () {
    final t = _speak(
      'welcome back to the channel I hope everyone had a great weekend '
      'today we are talking about',
    );
    expect(t.currentWordIndex, _wordIndexOf(doc, 'about'));
  });

  test('an ad-lib never drags the highlight far ahead', () {
    final t = _speak('welcome back to the channel the key is that');
    // "the key is" appears much later; three words are not enough to jump.
    expect(t.currentWordIndex, lessThan(_wordIndexOf(doc, 'today') + 2));
  });

  test('follows a skipped sentence once the reader is clearly past it', () {
    final t = _speak(
      'it takes ten seconds and it signals to your brain that the day has '
      'started the key is consistency not intensity',
      tracker: ScriptTracker(doc)
        ..jumpToWord(_wordIndexOf(doc, 'it', occurrence: 1)),
    );
    expect(t.currentWordIndex, doc.words.length - 1);
  });

  test('follows the reader back when a sentence is re-read', () {
    final t = _speak(
      'for example drink a glass of water as soon as you wake up '
      'for example drink a glass',
      tracker: ScriptTracker(doc)
        ..jumpToWord(_wordIndexOf(doc, 'for', occurrence: 1)),
    );
    expect(t.currentWordIndex, _wordIndexOf(doc, 'glass'));
  });

  test('tolerates recognizer slips and number formats', () {
    final t = _speak(
      'it takes 10 seconds end it signal to your brain that the day has started',
      tracker: ScriptTracker(doc)
        ..jumpToWord(_wordIndexOf(doc, 'it', occurrence: 1)),
    );
    expect(
      t.currentWordIndex,
      _wordIndexOf(doc, 'started.'.replaceAll('.', '')),
    );
  });

  test('rolls back when the recognizer revises earlier words', () {
    final t = ScriptTracker(doc);
    t.update(doc.normalizeSpeech('welcome back to the channel today we'));
    final before = t.currentWordIndex;
    // A revision replaces the tail with different words, then corrects again.
    t.update(
      doc.normalizeSpeech('welcome back to the channel to day we are walking'),
    );
    t.update(
      doc.normalizeSpeech('welcome back to the channel today we are talking'),
    );
    expect(before, _wordIndexOf(doc, 'we'));
    expect(t.currentWordIndex, _wordIndexOf(doc, 'talking'));
  });

  test('jumpToWord resumes from a tapped word mid-session', () {
    final t = _speak('welcome back to the channel');
    final target = _wordIndexOf(doc, 'instead');
    t.jumpToWord(target);
    expect(t.currentWordIndex, target - 1);
    t.update(
      doc.normalizeSpeech('welcome back to the channel instead start with'),
    );
    expect(t.currentWordIndex, _wordIndexOf(doc, 'with'));
  });

  test('a new transcript session keeps the position', () {
    final t = _speak('welcome back to the channel today we are');
    t.beginTranscript();
    t.update(doc.normalizeSpeech('talking about how'));
    expect(t.currentWordIndex, _wordIndexOf(doc, 'how'));
  });

  test('handles an empty script', () {
    final empty = ScriptDocument('   ');
    final t = ScriptTracker(empty);
    t.update(empty.normalizeSpeech('hello there'));
    expect(t.currentWordIndex, -1);
  });

  group('normalization', () {
    test('matches compounds, numbers, and contractions', () {
      final d = ScriptDocument(
        "We don't rebuild the on-boarding flow in twenty-five minutes; 18% faster.",
      );
      expect(d.units, [
        'we',
        'dont',
        'rebuild',
        'the',
        'on',
        'boarding',
        'flow',
        'in',
        '25',
        'minutes',
        '18',
        'percent',
        'faster',
      ]);
      expect(d.normalizeSpeech('onboarding'), ['on', 'boarding']);
      expect(
        ScriptDocument('our onboarding flow').normalizeSpeech('on boarding'),
        ['onboarding'],
      );
      expect(d.normalizeSpeech('25 minutes 18 percent'), [
        '25',
        'minutes',
        '18',
        'percent',
      ]);
    });

    test('near matches cover common recognizer slips', () {
      expect(TextNormalizer.isNearMatch('rebuild', 'rebuilt'), isTrue);
      expect(TextNormalizer.isNearMatch('ship', 'shipped'), isTrue);
      expect(TextNormalizer.isNearMatch('winds', 'wins'), isTrue);
      expect(TextNormalizer.isNearMatch('cat', 'dog'), isFalse);
      expect(TextNormalizer.isNearMatch('to', 'the'), isFalse);
    });
  });
}
