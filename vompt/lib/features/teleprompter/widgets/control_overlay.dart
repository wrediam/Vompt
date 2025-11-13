import 'package:flutter/material.dart';

class ControlOverlay extends StatelessWidget {
  final bool isVisible;
  final bool isPlaying;
  final bool isSpeechEnabled;
  final double scrollSpeed;
  final double fontSize;
  final VoidCallback onPlayPause;
  final Function(double) onSpeedChange;
  final Function(double) onFontSizeChange;
  final VoidCallback onSpeechToggle;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  const ControlOverlay({
    super.key,
    required this.isVisible,
    required this.isPlaying,
    required this.isSpeechEnabled,
    required this.scrollSpeed,
    required this.fontSize,
    required this.onPlayPause,
    required this.onSpeedChange,
    required this.onFontSizeChange,
    required this.onSpeechToggle,
    required this.onBack,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Container(
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
                // Top row - status and close
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close
                      _buildIconButton(
                        icon: Icons.close,
                        onPressed: onBack,
                      ),
                      
                      // Status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSpeechEnabled
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSpeechEnabled 
                                ? Colors.green.withValues(alpha: 0.5)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic,
                              color: isSpeechEnabled ? Colors.green : Colors.grey,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isSpeechEnabled ? 'Listening' : 'Paused',
                              style: TextStyle(
                                color: isSpeechEnabled ? Colors.green : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Reset
                      _buildIconButton(
                        icon: Icons.refresh_rounded,
                        onPressed: onSettings,
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
                        onPressed: () => onFontSizeChange(fontSize - 2),
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
                          '${fontSize.toInt()}',
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
                        onPressed: () => onFontSizeChange(fontSize + 2),
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Main speech button
                      GestureDetector(
                        onTap: onSpeechToggle,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSpeechEnabled ? Colors.red : Colors.green,
                            boxShadow: [
                              BoxShadow(
                                color: (isSpeechEnabled ? Colors.red : Colors.green)
                                    .withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            isSpeechEnabled ? Icons.stop_rounded : Icons.mic_rounded,
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
        ),
      ),
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
