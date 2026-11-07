import 'dart:convert';

/// A saved practice take of one script.
class PracticeSession {
  final String id;
  final String documentId;
  final DateTime createdAt;
  final double durationSeconds;
  final double wordsPerMinute;
  final Map<String, int> fillers;
  final int skippedWords;
  final int misreads;
  final int repeats;
  final int longPauses;
  final double accuracy;
  final double completion;

  const PracticeSession({
    required this.id,
    required this.documentId,
    required this.createdAt,
    required this.durationSeconds,
    required this.wordsPerMinute,
    required this.fillers,
    required this.skippedWords,
    required this.misreads,
    required this.repeats,
    required this.longPauses,
    required this.accuracy,
    required this.completion,
  });

  int get fillerCount => fillers.values.fold(0, (a, b) => a + b);

  double get fillersPerMinute =>
      durationSeconds < 5 ? 0 : fillerCount / durationSeconds * 60;

  Map<String, dynamic> toMap() => {
    'id': id,
    'documentId': documentId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'durationSeconds': durationSeconds,
    'wordsPerMinute': wordsPerMinute,
    'fillers': jsonEncode(fillers),
    'skippedWords': skippedWords,
    'misreads': misreads,
    'repeats': repeats,
    'longPauses': longPauses,
    'accuracy': accuracy,
    'completion': completion,
  };

  factory PracticeSession.fromMap(Map<String, dynamic> map) => PracticeSession(
    id: map['id'] as String,
    documentId: map['documentId'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    durationSeconds: (map['durationSeconds'] as num).toDouble(),
    wordsPerMinute: (map['wordsPerMinute'] as num).toDouble(),
    fillers: (jsonDecode(map['fillers'] as String) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    ),
    skippedWords: map['skippedWords'] as int,
    misreads: map['misreads'] as int,
    repeats: map['repeats'] as int,
    longPauses: map['longPauses'] as int,
    accuracy: (map['accuracy'] as num).toDouble(),
    completion: (map['completion'] as num).toDouble(),
  );
}
