import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/intelligent_teleprompter_provider.dart';

class IntelligentTeleprompterControls extends StatelessWidget {
  final VoidCallback onClose;

  const IntelligentTeleprompterControls({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<IntelligentTeleprompterProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0.0, 0.08, 0.92, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top row - status and controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close
                      _buildIconButton(
                        icon: Icons.close,
                        onPressed: onClose,
                      ),
                      
                      // Status with pulsing animation
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: provider.isSpeechActive
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: provider.isSpeechActive 
                                ? Colors.green.withValues(alpha: 0.5)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (provider.isSpeechActive)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Icon(
                              Icons.mic,
                              color: provider.isSpeechActive ? Colors.green : Colors.grey,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              provider.isSpeechActive ? 'Listening' : 'Paused',
                              style: TextStyle(
                                color: provider.isSpeechActive ? Colors.green : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Mirror toggle
                      _buildIconButton(
                        icon: provider.isMirrored ? Icons.flip : Icons.flip_outlined,
                        onPressed: provider.toggleMirror,
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom row - all controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Font decrease
                      _buildIconButton(
                        icon: Icons.text_decrease,
                        onPressed: provider.decreaseFontSize,
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Font size display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          '${provider.fontSize.toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Font increase
                      _buildIconButton(
                        icon: Icons.text_increase,
                        onPressed: provider.increaseFontSize,
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Reset
                      _buildIconButton(
                        icon: Icons.refresh_rounded,
                        onPressed: provider.reset,
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Main speech button
                      GestureDetector(
                        onTap: () async {
                          if (provider.isSpeechActive) {
                            await provider.stopSpeechRecognition();
                          } else {
                            final success = await provider.startSpeechRecognition();
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to start speech recognition. Please check microphone permissions.'),
                                  duration: Duration(seconds: 3),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: provider.isSpeechActive ? Colors.red : Colors.green,
                            boxShadow: [
                              BoxShadow(
                                color: (provider.isSpeechActive ? Colors.red : Colors.green)
                                    .withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            provider.isSpeechActive ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
