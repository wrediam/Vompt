import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/readable_width.dart';

import '../../../core/constants/colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../data/models/document.dart';
import '../../../data/models/script_version.dart';
import '../../../data/repositories/version_repository.dart';
import '../../../services/script_assistant.dart';
import '../../documents/providers/documents_provider.dart';
import '../../history/practice_history_screen.dart';
import '../../teleprompter/screens/intelligent_teleprompter_screen.dart';
import '../../versions/versions_screen.dart';
import '../providers/editor_provider.dart';
import '../widgets/assist_sheet.dart';

class EditorScreen extends StatefulWidget {
  final Document document;

  /// A just-created script: focus the title so it gets named first.
  final bool isNew;

  const EditorScreen({super.key, required this.document, this.isNew = false});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  final _contentFocus = FocusNode();
  late final EditorProvider _editor;
  late final DocumentsProvider _documents;
  final _versions = VersionRepository();

  @override
  void initState() {
    super.initState();
    _editor = context.read<EditorProvider>();
    _documents = context.read<DocumentsProvider>();
    _editor.loadDocument(
      widget.document,
      persist: (doc) async {
        final ok = await _documents.updateDocument(doc);
        if (!ok) throw StateError('Save failed');
        // Long editing sessions leave a trail of versions.
        await _versions.checkpoint(
          doc,
          VersionKind.edit,
          minGap: VersionRepository.editInterval,
        );
      },
    );
    // Capture changes made elsewhere (e.g. Vompt Studio) before editing.
    _versions.checkpoint(widget.document, VersionKind.edit);
    _title = TextEditingController(
      text: widget.isNew ? '' : widget.document.title,
    )..addListener(() => _editor.updateTitle(_title.text));
    _content = TextEditingController(text: widget.document.content)
      ..addListener(() => _editor.updateContent(_content.text));
  }

  @override
  void dispose() {
    // Save anything typed in the last second before leaving, without
    // clearing an editor that has since opened another script.
    final id = widget.document.id;
    _editor.save().whenComplete(() {
      final saved = _editor.currentDocument;
      if (saved?.id == id) {
        _versions.checkpoint(saved!, VersionKind.edit);
        _editor.clear();
      }
    });
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _rehearse() async {
    FocusScope.of(context).unfocus();
    await _editor.save();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IntelligentTeleprompterScreen(
          document: _editor.getUpdatedDocument(),
        ),
      ),
    );
  }

  /// Replaces the script text, saving a version before and after so the
  /// change is always one tap away from being undone.
  Future<void> _replaceScript(
    String text, {
    required VersionKind kind,
    String? label,
  }) async {
    await _editor.save();
    await _versions.checkpoint(_editor.getUpdatedDocument(), VersionKind.edit);
    _content.text = text;
    await _editor.save();
    await _versions.checkpoint(
      _editor.getUpdatedDocument(),
      kind,
      label: label,
    );
  }

  Future<void> _assist() async {
    FocusScope.of(context).unfocus();
    final result = await showAssistSheet(context, script: _content.text);
    if (result == null || !mounted) return;
    final before = _content.text;
    await _replaceScript(
      result.task.rewrites ? result.text : '${result.text}\n\n$before',
      kind: VersionKind.assist,
      label: result.task.rewrites ? result.task.label : 'Opening line',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.task.rewrites
                ? 'Rewritten. The original is in Versions.'
                : 'Opening line added',
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.ink,
            onPressed: () => _replaceScript(before, kind: VersionKind.edit),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<void> _openVersions() async {
    FocusScope.of(context).unfocus();
    await _editor.save();
    if (!mounted) return;
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VersionsScreen(
          document: _editor.getUpdatedDocument(),
          onRestore: (v) => _replaceScript(
            v.content,
            kind: VersionKind.restore,
            label: friendlyWhen(v.createdAt),
          ),
        ),
      ),
    );
    if (restored == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Version restored. Your previous text is in Versions.'),
        ),
      );
    }
  }

  void _history() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PracticeHistoryScreen(document: _editor.getUpdatedDocument()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const bare = InputDecoration(
      filled: false,
      border: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      isCollapsed: true,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Assist',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: _assist,
          ),
          IconButton(
            tooltip: 'Versions',
            icon: const Icon(Icons.history_rounded),
            onPressed: _openVersions,
          ),
          IconButton(
            tooltip: 'Practice history',
            icon: const Icon(Icons.insights_rounded),
            onPressed: _history,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 12),
            child: FilledButton.icon(
              onPressed: _rehearse,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Rehearse'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: TextField(
                  controller: _title,
                  autofocus: widget.isNew,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _contentFocus.requestFocus(),
                  style: text.headlineSmall,
                  decoration: bare.copyWith(hintText: 'Untitled script'),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _content,
                    focusNode: _contentFocus,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textAlignVertical: TextAlignVertical.top,
                    style: text.bodyLarge?.copyWith(fontSize: 18, height: 1.6),
                    decoration: bare.copyWith(
                      hintText:
                          'Write what you want to say, the way you would say it. '
                          'Or jot down bullet points and tap Assist to draft a script.',
                      hintMaxLines: 4,
                    ),
                  ),
                ),
              ),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorProvider>();
    final words = editor.wordCount;
    final seconds = (words / ScriptAssistant.defaultPace * 60).round();
    final m = seconds ~/ 60, s = (seconds % 60).toString().padLeft(2, '0');
    final saveLabel = editor.isSaving
        ? 'Saving'
        : editor.hasUnsavedChanges
        ? 'Edited'
        : 'Saved';
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Text('$words', style: AppTheme.figureSmall),
          Text(
            words == 1 ? ' word' : ' words',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 16),
          Text('$m:$s', style: AppTheme.figureSmall),
          Text(
            ' at ${ScriptAssistant.defaultPace} wpm',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Text(saveLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
