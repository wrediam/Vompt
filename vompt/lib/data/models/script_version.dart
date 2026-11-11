/// Why a version was saved.
enum VersionKind {
  /// The script's text when versioning started.
  original,

  /// Edits in the app's editor.
  edit,

  /// Edits made in Vompt Studio in a browser.
  studio,

  /// A rewrite accepted from Assist ([ScriptVersion.label] names the tool).
  assist,

  /// An earlier version brought back ([ScriptVersion.label] names when it was from).
  restore,
}

/// A saved snapshot of a script.
class ScriptVersion {
  final String id;
  final String documentId;
  final DateTime createdAt;
  final String title;
  final String content;
  final VersionKind kind;
  final String? label;

  const ScriptVersion({
    required this.id,
    required this.documentId,
    required this.createdAt,
    required this.title,
    required this.content,
    required this.kind,
    this.label,
  });

  int get wordCount =>
      content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;

  /// How the timeline names this version.
  String get headline => switch (kind) {
    VersionKind.original => 'First version',
    VersionKind.edit => 'Edited',
    VersionKind.studio => 'Edited in Studio',
    VersionKind.assist => label == null ? 'Assist' : 'Assist: $label',
    VersionKind.restore => label == null ? 'Restored' : 'Restored from $label',
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'documentId': documentId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'title': title,
    'content': content,
    'kind': kind.name,
    'label': label,
  };

  factory ScriptVersion.fromMap(Map<String, dynamic> map) => ScriptVersion(
    id: map['id'] as String,
    documentId: map['documentId'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    title: map['title'] as String,
    content: map['content'] as String,
    kind: VersionKind.values.firstWhere(
      (k) => k.name == map['kind'],
      orElse: () => VersionKind.edit,
    ),
    label: map['label'] as String?,
  );
}
