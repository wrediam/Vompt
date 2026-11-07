import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'core/constants/app_constants.dart';
import 'data/database/database_helper.dart';
import 'data/models/document.dart';
import 'data/models/practice_session.dart';
import 'data/repositories/document_repository.dart';
import 'data/repositories/practice_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/documents/screens/document_list_screen.dart';
import 'features/editor/screens/editor_screen.dart';
import 'features/editor/widgets/assist_sheet.dart';
import 'features/history/practice_history_screen.dart';
import 'features/teleprompter/engine/performance_analyzer.dart';
import 'features/teleprompter/providers/intelligent_teleprompter_provider.dart';
import 'features/teleprompter/screens/intelligent_teleprompter_screen.dart';
import 'services/script_assistant.dart';

/// Demo content and direct-to-screen launches for App Store screenshots.
///
/// Debug builds only, and only when the app's Documents folder holds a
/// showcase.txt naming a scene: library, editor, assist, prompter, summary or
/// history. tools/screenshots.py writes it into the simulator before launch.
class Showcase {
  static String? _scene;
  static String? get scene => _scene;

  /// Reads the requested scene; call before runApp.
  static Future<void> init() async {
    if (!kDebugMode) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/showcase.txt');
      if (await file.exists()) {
        final value = (await file.readAsString()).trim();
        _scene = value.isEmpty ? null : value;
      }
    } catch (_) {}
  }

  static final _now = DateTime.now();

  static final _docs = [
    Document(
      id: 'demo-quarterly',
      title: 'Quarterly update',
      content:
          'Good morning everyone, and thank you for joining us.\n\n'
          'Over the last quarter our team shipped three major features. First, we rebuilt '
          'the onboarding flow from scratch. New users now reach their first success in '
          'under two minutes. Second, we launched offline mode, which was the most '
          'requested feature in our survey. Third, we cut the average page load time in half.\n\n'
          'These changes had a real impact on our numbers. Weekly active users grew by 18%, '
          'and churn dropped to its lowest level in two years.\n\n'
          'Looking ahead, we will focus on collaboration features. Teams have told us they '
          'want to share projects and leave comments in real time. We plan to deliver a '
          'first version by the end of March.\n\n'
          'Thank you, and I am happy to take your questions.',
      createdAt: _now.subtract(const Duration(days: 3)),
      modifiedAt: _now.subtract(const Duration(minutes: 12)),
    ),
    Document(
      id: 'demo-morning',
      title: 'Morning routine, episode 12',
      content:
          'Welcome back to the channel. Today we are talking about how to build a morning '
          'routine that actually sticks.\n\n'
          'Most people try to change everything at once, and that is exactly why they fail. '
          'Instead, start with one small habit. For example, drink a glass of water as soon as '
          'you wake up. It takes ten seconds, and it signals to your brain that the day has started.\n\n'
          'Once that feels automatic, add a second habit, like a five-minute walk outside. The key '
          'is consistency, not intensity. Track your streak on a calendar and celebrate small wins.\n\n'
          'In 30 days, you will be surprised at how much has changed.',
      createdAt: _now.subtract(const Duration(days: 9)),
      modifiedAt: _now.subtract(const Duration(hours: 5)),
    ),
    Document(
      id: 'demo-launch',
      title: 'Product launch keynote',
      content:
          'Today we are introducing something we have been working on for two years.\n\n'
          'It started with a simple question: why does planning a trip still take twelve browser '
          'tabs and three group chats? So we built one place where your whole group can plan '
          'together, vote on ideas, and book in a single tap.\n\n'
          'In our beta, groups finished planning in half the time. And ninety percent of them '
          'said they would never go back.\n\n'
          'It is available today, on every platform, and it is free to start.',
      createdAt: _now.subtract(const Duration(days: 14)),
      modifiedAt: _now.subtract(const Duration(days: 1, hours: 3)),
    ),
    Document(
      id: 'demo-podcast',
      title: 'Podcast intro',
      content:
          'Welcome to Studio Notes, the show about the craft behind great audio. Every week '
          'we sit down with the people who make the sounds you love, and ask them how they '
          'actually do it.\n\nThis week: what a radio host learned from forty years of live mornings.',
      createdAt: _now.subtract(const Duration(days: 20)),
      modifiedAt: _now.subtract(const Duration(days: 2)),
    ),
    Document(
      id: 'demo-toast',
      title: 'Toast for Sam and Priya',
      content:
          'For those who do not know me, I have been Sam\'s friend since the third grade, '
          'which means I have seen every haircut, every band, and every terrible idea. '
          'Priya, you are the best idea he has ever had.',
      createdAt: _now.subtract(const Duration(days: 30)),
      modifiedAt: _now.subtract(const Duration(days: 6)),
    ),
  ];

  static PracticeSession _take(
    String doc,
    int daysAgo,
    double minutes,
    double wpm,
    Map<String, int> fillers, {
    int skipped = 0,
    double accuracy = 0.96,
  }) => PracticeSession(
    id: '$doc-$daysAgo-${fillers.length}',
    documentId: doc,
    createdAt: _now.subtract(Duration(days: daysAgo, hours: 2)),
    durationSeconds: minutes * 60,
    wordsPerMinute: wpm,
    fillers: fillers,
    skippedWords: skipped,
    misreads: 1,
    repeats: fillers.length > 2 ? 2 : 0,
    longPauses: 0,
    accuracy: accuracy,
    completion: 1,
  );

  static final _takes = [
    _take(
      'demo-morning',
      8,
      1.2,
      184,
      {'um': 3, 'like': 2, 'so': 1},
      skipped: 14,
      accuracy: 0.84,
    ),
    _take(
      'demo-morning',
      6,
      1.1,
      172,
      {'um': 2, 'like': 2},
      skipped: 6,
      accuracy: 0.9,
    ),
    _take('demo-morning', 4, 1.15, 163, {'um': 2, 'uh': 1}),
    _take('demo-morning', 2, 1.1, 156, {'um': 1, 'like': 1}),
    _take('demo-morning', 0, 1.05, 151, {'um': 1}, accuracy: 0.98),
    _take('demo-quarterly', 1, 1.0, 153, {'um': 2, 'like': 1}),
    _take('demo-launch', 2, 0.9, 147, {}, accuracy: 0.99),
  ];

  /// Replaces whatever is on the device with the demo library.
  static Future<void> seed() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(AppConstants.documentsTable);
    await db.delete(AppConstants.practiceTable);
    final docs = DocumentRepository();
    for (final d in _docs) {
      await docs.create(d);
    }
    final practice = PracticeRepository();
    for (final t in _takes) {
      await practice.save(t);
    }
    final settings = SettingsRepository();
    await settings.saveSettings(
      (await settings.getSettings()).copyWith(
        fontSize: 40,
        mirrorMode: false,
        showStats: true,
        centerText: true,
      ),
    );
  }

  static Widget? home() {
    final doc = _docs.first;
    switch (scene) {
      case null:
        return null;
      case 'editor':
        return EditorScreen(document: _docs[2]);
      case 'assist':
        return _AssistScene(document: _docs[2]);
      case 'history':
        return PracticeHistoryScreen(document: _docs[1]);
      case 'prompter':
        return IntelligentTeleprompterScreen(
          document: doc,
          warmUp: false,
          onLoaded: _stagePrompter,
        );
      case 'summary':
        return IntelligentTeleprompterScreen(
          document: doc,
          warmUp: false,
          onLoaded: _stageSummary,
        );
      default:
        return const DocumentListScreen();
    }
  }

  static void _stagePrompter(IntelligentTeleprompterProvider p) {
    p.showcase(
      word: 26,
      status: PrompterStatus.listening,
      elapsed: const Duration(seconds: 11),
      stats: _stats(fillers: {'um': 1}, seconds: 11, words: 28),
    );
  }

  static void _stageSummary(IntelligentTeleprompterProvider p) {
    final words = p.scriptWords;
    final skipFrom = words.indexOf('Weekly');
    final shipped = words.indexOf('shipped');
    final stats = _stats(
      fillers: {'um': 2, 'like': 1},
      seconds: 58,
      words: 148,
      skipped: [SkippedRange(skipFrom, words.indexOf('years.', skipFrom))],
      misreads: [Misread(shipped, 'shipped', 'ship')],
      repeats: 1,
    );
    p.showcase(
      word: p.scriptWords.length - 1,
      status: PrompterStatus.finished,
      elapsed: const Duration(seconds: 62),
      stats: stats,
    );
  }

  static PerformanceStats _stats({
    required Map<String, int> fillers,
    required double seconds,
    required int words,
    List<SkippedRange> skipped = const [],
    List<Misread> misreads = const [],
    int repeats = 0,
  }) => PerformanceStats(
    fillers: fillers,
    spokenWords: words,
    scriptWordsCovered: words,
    matchedWords: words - misreads.length,
    misreads: misreads,
    skipped: skipped,
    repeats: repeats,
    extraWords: const [],
    longPauses: 0,
    longestPause: 0,
    speakingSeconds: seconds,
  );
}

/// The editor with the Assist sheet open on a finished rewrite.
class _AssistScene extends StatefulWidget {
  final Document document;
  const _AssistScene({required this.document});

  @override
  State<_AssistScene> createState() => _AssistSceneState();
}

class _AssistSceneState extends State<_AssistScene> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showAssistSheet(
        context,
        script: widget.document.content,
        preview: const AssistResult(
          ScriptTask.speakable,
          "Today we're introducing something we've spent two years on.\n\n"
          "It started with one question: why does planning a trip still take twelve browser tabs "
          "and three group chats? So we built one place where your whole group plans together, "
          "votes on ideas, and books in a single tap.\n\n"
          "In our beta, groups finished planning in half the time. Ninety percent said they'd "
          "never go back.\n\nIt's out today, on every platform, and it's free to start.",
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => EditorScreen(document: widget.document);
}
