import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/documents_provider.dart';
import '../widgets/document_list_item.dart';
import '../../editor/screens/editor_screen.dart';
import '../../remote/screens/remote_control_screen.dart';
import '../../remote/screens/active_remote_control_screen.dart';
import '../../remote/providers/server_provider.dart';
import '../../../shared/widgets/minimal_dialog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/remote_control_service.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  final RemoteControlService _remoteControlService = RemoteControlService();
  StreamSubscription<bool>? _clientConnectionSubscription;

  @override
  void initState() {
    super.initState();
    // Load documents when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().loadDocuments();
    });
    
    // Listen for remote client connections
    _clientConnectionSubscription = _remoteControlService.onClientConnectionChange.listen((connected) {
      if (connected && mounted) {
        // Navigate to active remote control screen when client connects
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ActiveRemoteControlScreen(),
          ),
        );
      }
      // Note: Disconnection is handled by the ActiveRemoteControlScreen itself
    });
  }

  Future<void> _createNewDocument() async {
    final title = await MinimalDialog.showTextInput(
      context: context,
      title: 'New Script',
      placeholder: 'Script title',
      confirmText: 'Create',
    );

    if (title != null && title.isNotEmpty && mounted) {
      final provider = context.read<DocumentsProvider>();
      final document = await provider.createDocument(title);
      
      if (document != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EditorScreen(document: document),
          ),
        );
      }
    }
  }

  Future<void> _renameDocument(String documentId, String currentTitle) async {
    final newTitle = await MinimalDialog.showTextInput(
      context: context,
      title: 'Rename Script',
      initialValue: currentTitle,
      placeholder: 'Script title',
      confirmText: 'Rename',
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != currentTitle && mounted) {
      final provider = context.read<DocumentsProvider>();
      final document = provider.getDocument(documentId);
      if (document != null) {
        await provider.updateDocument(
          document.copyWith(title: newTitle),
        );
      }
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    await context.read<DocumentsProvider>().deleteDocument(documentId);
  }

  void _openDocument(dynamic document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditorScreen(document: document),
      ),
    );
  }

  @override
  void dispose() {
    _clientConnectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DocumentsProvider>(
        builder: (context, provider, child) {
          return CustomScrollView(
            slivers: [
              // Large Cupertino-style header
              CupertinoSliverNavigationBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                largeTitle: Text(
                  'Scripts',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                trailing: Consumer<ServerProvider>(
                  builder: (context, serverProvider, child) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RemoteControlScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: serverProvider.isRunning
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.wifi,
                          color: serverProvider.isRunning
                              ? Colors.green
                              : Theme.of(context).iconTheme.color,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Content
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 15),
                  ),
                )
              else if (provider.error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: provider.loadDocuments,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (provider.documents.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No scripts yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to create your first script',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppConstants.screenPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final document = provider.documents[index];
                        return DocumentListItem(
                          document: document,
                          onTap: () => _openDocument(document),
                          onRename: () => _renameDocument(document.id, document.title),
                          onDelete: () => _deleteDocument(document.id),
                        );
                      },
                      childCount: provider.documents.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewDocument,
        child: const Icon(Icons.add),
      ),
    );
  }
}
