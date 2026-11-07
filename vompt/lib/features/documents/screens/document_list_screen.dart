import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/readable_width.dart';

import '../../../core/constants/colors.dart';
import '../../../data/models/document.dart';
import '../../editor/screens/editor_screen.dart';
import '../../remote/providers/server_provider.dart';
import '../../remote/screens/remote_control_screen.dart';
import '../providers/documents_provider.dart';
import '../widgets/document_list_item.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().loadDocuments();
    });
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${doc.title}"?'),
        content: const Text(
          'The script and its practice history will be removed from this iPhone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.tally),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<DocumentsProvider>().deleteDocument(doc.id);
      return true;
    }
    return false;
  }

  Future<void> _rename(Document doc) async {
    final controller = TextEditingController(text: doc.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename script'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    final trimmed = title?.trim() ?? '';
    if (trimmed.isNotEmpty && trimmed != doc.title && mounted) {
      await context.read<DocumentsProvider>().updateDocument(
        doc.copyWith(title: trimmed),
      );
    }
  }

  void _showActions(Document doc) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(sheet);
                _rename(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(sheet);
                context.read<DocumentsProvider>().duplicateDocument(doc);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.tally,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: AppColors.tally),
              ),
              onTap: () {
                Navigator.pop(sheet);
                _confirmDelete(doc);
              },
            ),
          ],
        ),
      ),
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
                  return DocumentListItem(
                    document: doc,
                    latestTake: provider.latestTake(doc.id),
                    onTap: () => _open(doc),
                    onLongPress: () => _showActions(doc),
                    onDelete: () => _confirmDelete(doc),
                  );
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
