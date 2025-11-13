import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/document.dart';
import '../providers/teleprompter_provider.dart';
import '../widgets/control_overlay.dart';
import '../widgets/scrolling_text.dart';

class TeleprompterScreen extends StatefulWidget {
  final Document document;

  const TeleprompterScreen({
    super.key,
    required this.document,
  });

  @override
  State<TeleprompterScreen> createState() => _TeleprompterScreenState();
}

class _TeleprompterScreenState extends State<TeleprompterScreen> {
  @override
  void initState() {
    super.initState();
    // Set to fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Initialize teleprompter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeleprompterProvider>().loadDocument(widget.document);
    });
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<TeleprompterProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              // Main scrolling text
              ScrollingText(
                content: widget.document.content,
                fontSize: provider.settings.fontSize,
                scrollSpeed: provider.settings.scrollSpeed,
                mirrorMode: provider.settings.mirrorMode,
                darkMode: provider.settings.darkMode,
                highlightColor: provider.settings.highlightColor,
                currentWordIndex: provider.currentWordIndex,
                isPlaying: provider.isPlaying,
                scrollController: provider.scrollController,
              ),
              
              // Control overlay (auto-hides)
              ControlOverlay(
                isVisible: provider.isOverlayVisible,
                isPlaying: provider.isPlaying,
                isSpeechEnabled: provider.isSpeechRecognitionActive,
                scrollSpeed: provider.settings.scrollSpeed,
                fontSize: provider.settings.fontSize,
                onPlayPause: provider.togglePlayPause,
                onSpeedChange: provider.updateScrollSpeed,
                onFontSizeChange: provider.updateFontSize,
                onSpeechToggle: provider.toggleSpeechRecognition,
                onBack: () => Navigator.of(context).pop(),
                onSettings: () => provider.showSettings(),
              ),
              
              // Tap detector to show/hide overlay
              Positioned.fill(
                child: GestureDetector(
                  onTap: provider.toggleOverlay,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
