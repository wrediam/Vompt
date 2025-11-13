import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/document.dart';
import '../providers/intelligent_teleprompter_provider.dart';
import '../widgets/intelligent_teleprompter_controls.dart';

class IntelligentTeleprompterScreen extends StatefulWidget {
  final Document document;

  const IntelligentTeleprompterScreen({super.key, required this.document});

  @override
  State<IntelligentTeleprompterScreen> createState() =>
      _IntelligentTeleprompterScreenState();
}

class _IntelligentTeleprompterScreenState
    extends State<IntelligentTeleprompterScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showControls = true;
  IntelligentTeleprompterProvider? _provider;
  int _lastScrolledLine = -1;

  @override
  void initState() {
    super.initState();
    
    // Force landscape orientation FIRST
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Load script into provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<IntelligentTeleprompterProvider>();
      _provider!.loadScript(widget.document.content);
      _provider!.addListener(_scrollToCurrentWord);
      
      // Update screen dimensions for web UI - get size AFTER orientation is set
      final size = MediaQuery.of(context).size;
      // Ensure we send landscape dimensions (width > height)
      final landscapeWidth = size.width > size.height ? size.width : size.height;
      final landscapeHeight = size.width > size.height ? size.height : size.width;
      _provider!.updateScreenDimensions(landscapeWidth, landscapeHeight);
      print('📱 Sending landscape dimensions: ${landscapeWidth}x$landscapeHeight');
      
      // Hide controls by default if in remote mode (web client connected)
      // Access RemoteControlService through the provider
      if (_provider!.remoteControlService.hasActiveClient) {
        setState(() {
          _showControls = false;
        });
        print('📱 Remote mode detected - hiding controls by default');
      }
      
      print('📜 Scroll listener added to provider');
    });

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _scrollToCurrentWord() {
    if (_provider == null) {
      print('📜 Provider is null');
      return;
    }

    if (!_scrollController.hasClients) {
      print('📜 Scroll controller has no clients');
      return;
    }

    final currentIndex = _provider!.currentWordIndex;
    if (currentIndex < 0) {
      return;
    }

    final totalWords = _provider!.scriptWords.length;
    if (totalWords == 0) return;

    final fontSize = _provider!.fontSize;
    final screenWidth = MediaQuery.of(context).size.width - 64; // Account for padding

    // Estimate words per line based on font size and screen width
    // Average word length is about 5 characters, each character is roughly fontSize * 0.6 wide
    final avgWordWidth = fontSize * 5 * 0.6;
    final wordsPerLine = (screenWidth / avgWordWidth).floor().clamp(1, 50);

    // Calculate which line the current word is on
    final currentLine = (currentIndex / wordsPerLine).floor();

    // Only scroll if we've moved to a new line
    if (currentLine == _lastScrolledLine) {
      return; // Still on same line, don't scroll
    }

    _lastScrolledLine = currentLine;

    print('📜 Line changed to: $currentLine (word $currentIndex, ~$wordsPerLine words/line)');
    
    // Calculate line height - decrease multiplier as font size increases
    // Small fonts (16-32): 1.4x multiplier
    // Large fonts (60-72): 1.1x multiplier
    final lineHeightMultiplier = 1.4 - ((fontSize - 16) / 186.67); // Decreases from 1.4 to 1.1
    final lineHeight = fontSize * lineHeightMultiplier;

    // Calculate scroll position to keep current line in upper-middle of screen
    final maxScroll = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Position of current line in content
    final linePosition = currentLine * lineHeight;

    // Scroll to keep line at 35% from top (upper-middle)
    final targetScroll = linePosition - (viewportHeight * 0.35);
    final centeredScroll = targetScroll.clamp(0.0, maxScroll);

    print('📜 Scrolling to line $currentLine at position: ${centeredScroll.toStringAsFixed(1)}');

    _scrollController.animateTo(
      centeredScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    // Remove listener
    _provider?.removeListener(_scrollToCurrentWord);

    // Stop speech recognition when leaving the screen
    if (_provider != null && _provider!.isSpeechActive) {
      _provider!.stopSpeechRecognition();
    }

    // Restore orientation to all
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Main teleprompter display
            Consumer<IntelligentTeleprompterProvider>(
              builder: (context, provider, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(provider.isMirrored ? -1.0 : 1.0, 1.0),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 100,
                      ),
                      child: _buildScriptWithHighlighting(provider),
                    ),
                  ),
                );
              },
            ),

            // Controls overlay
            if (_showControls)
              IntelligentTeleprompterControls(
                onClose: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScriptWithHighlighting(
    IntelligentTeleprompterProvider provider,
  ) {
    final words = provider.scriptWords;
    final currentIndex = provider.currentWordIndex;

    return Wrap(
      alignment: WrapAlignment.center, // Center the text
      spacing: 8,
      runSpacing: 0, // Reduce vertical spacing between lines
      children: List.generate(words.length, (index) {
        final isCurrentWord = index == currentIndex;
        final isPastWord = index < currentIndex;

        return Text(
          words[index],
          style: TextStyle(
            fontSize: provider.fontSize,
            fontWeight: FontWeight.w400, // Same weight for all words
            color: isCurrentWord
                ? Colors.yellow
                : isPastWord
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white,
            height: 1.2, // Reduce from 1.8 to 1.2
            letterSpacing: 0.5,
            backgroundColor: isCurrentWord
                ? Colors.yellow.withValues(alpha: 0.15)
                : null,
            shadows: isCurrentWord
                ? [const Shadow(color: Colors.yellow, blurRadius: 10)]
                : null,
          ),
        );
      }),
    );
  }
}
