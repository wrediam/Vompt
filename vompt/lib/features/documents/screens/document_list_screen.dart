import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/readable_width.dart';

import '../../../core/constants/colors.dart';
import '../../../core/utils/dates.dart';
import '../../../data/models/document.dart';
import '../../../data/models/script_version.dart';
import '../../../data/repositories/version_repository.dart';
import '../../../shared/widgets/lift_menu.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/vompt_dialog.dart';
import '../../editor/screens/editor_screen.dart';
import '../../teleprompter/screens/intelligent_teleprompter_screen.dart';
import '../../versions/versions_screen.dart';
import '../../remote/providers/server_provider.dart';
import '../../remote/screens/remote_control_screen.dart';
import '../providers/documents_provider.dart';
import '../widgets/document_list_item.dart';

class DocumentListScreen extends StatefulWidget {
  /// Screenshots only (see showcase.dart): opens this script's menu on load.
  final String? showcaseMenuFor;

  const DocumentListScreen({super.key, this.showcaseMenuFor});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  final _search = TextEditingController();

  /// Rows rise in, one after another, when the list first appears.
  bool _entrance = true;
  final _showcaseRow = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().loadDocuments();
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _entrance = false);
    });
    final showcase = widget.showcaseMenuFor;
    if (showcase != null) {
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        final doc = context.read<DocumentsProvider>().getDocument(showcase);
        final row = _showcaseRow.currentContext;
        if (row == null || !row.mounted || doc == null) return;
        _showActions(doc, row);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Document document, {bool isNew = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(document: document, isNew: isNew),
      ),
    );
    if (mounted) context.read<DocumentsProvider>().refreshTakes();
  }

  Future<void> _create() async {
    final doc = await context.read<DocumentsProvider>().createDocument(
      'Untitled script',
    );
    if (doc != null && mounted) _open(doc, isNew: true);
  }

  Future<bool> _confirmDelete(Document doc) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${doc.title}"?',
      message:
          'The script, its versions and its practice history will be removed from this iPhone.',
      confirmLabel: 'Delete script',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (ok && mounted) {
      await context.read<DocumentsProvider>().deleteDocument(doc.id);
      return true;
    }
    return false;
  }

  Future<void> _rename(Document doc) async {
    final title = await textDialog(
      context,
      title: 'Rename script',
      initial: doc.title,
      hint: 'Script title',
      confirmLabel: 'Rename',
    );
    final trimmed = title?.trim() ?? '';
    if (trimmed.isNotEmpty && trimmed != doc.title && mounted) {
      await context.read<DocumentsProvider>().updateDocument(
        doc.copyWith(title: trimmed),
      );
    }
  }

  void _rehearse(Document doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IntelligentTeleprompterScreen(document: doc),
      ),
    );
  }

  Future<void> _versions(Document doc) async {
    final docs = context.read<DocumentsProvider>();
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VersionsScreen(
          document: doc,
          onRestore: (v) async {
            final repo = VersionRepository();
            final current = docs.getDocument(doc.id) ?? doc;
            await repo.checkpoint(current, VersionKind.edit);
            final restored = current.copyWith(content: v.content);
            await docs.updateDocument(restored);
            await repo.checkpoint(
              restored,
              VersionKind.restore,
              label: friendlyWhen(v.createdAt),
            );
          },
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

  void _showActions(Document doc, BuildContext anchor) {
    final provider = context.read<DocumentsProvider>();
    showLiftMenu(
      context,
      anchor: anchor,
      preview: ScriptSummary(
        document: doc,
        latestTake: provider.latestTake(doc.id),
      ),
      items: [
        LiftMenuItem(
          icon: Icons.play_arrow_rounded,
          label: 'Rehearse',
          primary: true,
          onSelected: () => _rehearse(doc),
        ),
        LiftMenuItem(
          icon: Icons.history_rounded,
          label: 'Versions',
          onSelected: () => _versions(doc),
        ),
        LiftMenuItem(
          icon: Icons.edit_outlined,
          label: 'Rename',
          onSelected: () => _rename(doc),
        ),
        LiftMenuItem(
          icon: Icons.copy_rounded,
          label: 'Duplicate',
          onSelected: () => provider.duplicateDocument(doc),
        ),
        LiftMenuItem(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          destructive: true,
          onSelected: () => _confirmDelete(doc),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentsProvider>();
    final docs = provider.documents;
    final hasAny = provider.documentCount > 0;

    return Scaffold(
      body: ReadableWidth(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Scripts'),
              backgroundColor: AppColors.ink.withValues(alpha: 0.94),
              border: null,
              trailing: const _RemoteButton(),
            ),
            if (hasAny)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: provider.setSearchQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search scripts',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.muted,
                      ),
                      suffixIcon: provider.searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _search.clear();
                                provider.clearSearch();
                              },
                            ),
                    ),
                  ),
                ),
              ),
            if (provider.isLoading && !hasAny)
              const SliverFillRemaining(
                child: Center(child: CupertinoActivityIndicator(radius: 14)),
              )
            else if (provider.error != null && !hasAny)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Message(
                  title: 'Scripts didn\'t load',
                  body: provider.error!,
                  action: FilledButton(
                    onPressed: provider.loadDocuments,
                    child: const Text('Try again'),
                  ),
                ),
              )
            else if (!hasAny)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Message(
                  title: 'Write your first script',
                  body:
                      'Paste or type what you want to say. Vompt follows your voice, '
                      'scrolls as you read, and tells you how the take went.',
                  action: FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New script'),
                  ),
                ),
              )
            else if (docs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Message(
                  title: 'No matches',
                  body: 'No script mentions "${provider.searchQuery}".',
                ),
              )
            else
              SliverList.separated(
                itemCount: docs.length,
                separatorBuilder: (_, _) =>
                    const Divider(indent: 20, endIndent: 20),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final row = DocumentListItem(
                    key: doc.id == widget.showcaseMenuFor ? _showcaseRow : null,
                    document: doc,
                    latestTake: provider.latestTake(doc.id),
                    onTap: () => _open(doc),
                    onActions: (anchor) => _showActions(doc, anchor),
                    onDelete: () => _confirmDelete(doc),
                  );
                  return _entrance && i < 10
                      ? RiseIn(
                          key: ValueKey('rise-${doc.id}'),
                          delay: Duration(milliseconds: 60 + 55 * i),
                          child: row,
                        )
                      : row;
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      floatingActionButton: hasAny
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New script',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            )
          : null,
    );
  }
}

class _RemoteButton extends StatelessWidget {
  const _RemoteButton();

  @override
  Widget build(BuildContext context) {
    final running = context.watch<ServerProvider>().isRunning;
    return Semantics(
      button: true,
      label: running ? 'Web remote is on' : 'Web remote',
      child: GestureDetector(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RemoteControlScreen())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: running
                ? AppColors.tally.withValues(alpha: 0.16)
                : AppColors.raised,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cast_rounded,
                size: 18,
                color: running ? AppColors.tally : AppColors.paper,
              ),
              const SizedBox(width: 6),
              Text(
                running ? 'Remote on' : 'Remote',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: running ? AppColors.tally : AppColors.paper,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String title;
  final String body;
  final Widget? action;
  const _Message({required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.headlineSmall),
          const SizedBox(height: 10),
          Text(body, style: text.bodyLarge?.copyWith(color: AppColors.muted)),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}
