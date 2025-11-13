import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/document.dart';
import '../../documents/providers/documents_provider.dart';
import '../../teleprompter/screens/intelligent_teleprompter_screen.dart';
import '../../../services/remote_control_service.dart';
import 'dart:async';

/// Screen that shows when a remote web client is actively controlling the app
class ActiveRemoteControlScreen extends StatefulWidget {
  const ActiveRemoteControlScreen({super.key});

  @override
  State<ActiveRemoteControlScreen> createState() => _ActiveRemoteControlScreenState();
}

class _ActiveRemoteControlScreenState extends State<ActiveRemoteControlScreen> {
  final RemoteControlService _remoteControlService = RemoteControlService();
  StreamSubscription<void>? _playSubscription;
  StreamSubscription<String>? _documentSelectedSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Document? _currentDocument;
  String _status = 'Waiting for commands...';

  @override
  void initState() {
    super.initState();
    
    // Listen for connection changes (to detect disconnection)
    _connectionSubscription = _remoteControlService.onClientConnectionChange.listen((connected) {
      if (!connected && mounted) {
        // Client disconnected - pop this screen
        Navigator.of(context).pop();
      }
    });
    
    // Listen for document selection from web interface
    _documentSelectedSubscription = _remoteControlService.onDocumentSelected.listen((documentId) {
      _loadDocument(documentId);
    });
    
    // Listen for start speech command from web interface
    // The IntelligentTeleprompterProvider already listens to onStartSpeech
    // and will handle starting/stopping speech recognition
    // We don't need to do anything here - just let the provider handle it
    _playSubscription = _remoteControlService.onStartSpeech.listen((_) {
      print('🎮 Remote: Start speech command received (handled by provider)');
    });
    
    // Listen for control exit event from web interface
    _remoteControlService.onControlExit.listen((_) {
      print('🔙 Web UI exited control view - navigating back to remote control');
      // Only pop if we're on the teleprompter screen (one level deep)
      // This keeps us on the remote control screen, not back to scripts list
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _loadDocument(String documentId) async {
    final documentsProvider = context.read<DocumentsProvider>();
    final doc = documentsProvider.getDocument(documentId);
    
    if (doc != null && mounted) {
      setState(() {
        _currentDocument = doc;
        _status = 'Opening teleprompter...';
      });
      
      // Always navigate to teleprompter when document is selected from web
      // This ensures we get to the teleprompter screen from the remote control screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => IntelligentTeleprompterScreen(
            document: doc,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _playSubscription?.cancel();
    _documentSelectedSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button navigation
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const SizedBox(height: 40),
                  
                  // Title
                  const Text(
                    'Remote Control Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Status indicator
                  Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.wifi,
                  size: 50,
                  color: Colors.green,
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'Remote Control Connected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              const Text(
                'Your device is being controlled from the web interface',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    _buildStatusRow(
                      Icons.play_arrow,
                      _status,
                      _currentDocument != null ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Use the web interface to control the teleprompter',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String text, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
