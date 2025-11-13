import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../data/models/document.dart';
import '../providers/editor_provider.dart';
import '../../documents/providers/documents_provider.dart';
import '../../teleprompter/screens/intelligent_teleprompter_screen.dart';
import '../widgets/word_counter.dart';
import '../../../core/constants/app_constants.dart';

class EditorScreen extends StatefulWidget {
  final Document document;

  const EditorScreen({
    super.key,
    required this.document,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  late final EditorProvider _editorProvider;

  @override
  void initState() {
    super.initState();
    _editorProvider = context.read<EditorProvider>();
    _editorProvider.loadDocument(widget.document);
    
    _titleController.text = widget.document.title;
    _contentController.text = widget.document.content;

    _titleController.addListener(() {
      _editorProvider.updateTitle(_titleController.text);
    });

    _contentController.addListener(() {
      _editorProvider.updateContent(_contentController.text);
      // Check if auto-save should be triggered
      _checkAutoSave();
    });
  }

  void _checkAutoSave() {
    if (_editorProvider.shouldAutoSave()) {
      _saveDocument();
    }
  }

  Future<void> _saveDocument() async {
    final documentsProvider = context.read<DocumentsProvider>();

    _editorProvider.markAsSaving();
    
    try {
      final updatedDocument = _editorProvider.getUpdatedDocument();
      await documentsProvider.updateDocument(updatedDocument);
      _editorProvider.markAsSaved();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startTeleprompter() {
    // Save before starting teleprompter
    if (_editorProvider.hasUnsavedChanges) {
      _saveDocument();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IntelligentTeleprompterScreen(
          document: _editorProvider.getUpdatedDocument(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _editorProvider.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          if (_editorProvider.hasUnsavedChanges) {
            await _saveDocument();
          }
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_editorProvider.hasUnsavedChanges) {
                await _saveDocument();
              }
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: TextField(
            controller: _titleController,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(
              hintText: 'Document title',
              border: InputBorder.none,
            ),
            maxLines: 1,
          ),
          actions: [
            Consumer<EditorProvider>(
              builder: (context, provider, child) {
                if (provider.isSaving) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CupertinoActivityIndicator(radius: 10),
                  );
                }
                return IconButton(
                  icon: Icon(
                    provider.hasUnsavedChanges
                        ? Icons.save_outlined
                        : Icons.check_circle_outline,
                    color: provider.hasUnsavedChanges
                        ? Theme.of(context).colorScheme.primary
                        : Colors.green,
                  ),
                  onPressed: provider.hasUnsavedChanges ? _saveDocument : null,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _startTeleprompter,
              tooltip: 'Start Teleprompter',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.screenPadding),
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Start typing your script...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),
            Consumer<EditorProvider>(
              builder: (context, provider, child) {
                return WordCounter(
                  wordCount: provider.wordCount,
                  characterCount: provider.characterCount,
                  estimatedReadingTime: provider.estimatedReadingTime,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
