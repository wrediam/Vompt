import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class ScrollingText extends StatelessWidget {
  final String content;
  final double fontSize;
  final double scrollSpeed;
  final bool mirrorMode;
  final bool darkMode;
  final Color highlightColor;
  final int currentWordIndex;
  final bool isPlaying;
  final ScrollController scrollController;

  const ScrollingText({
    super.key,
    required this.content,
    required this.fontSize,
    required this.scrollSpeed,
    required this.mirrorMode,
    required this.darkMode,
    required this.highlightColor,
    required this.currentWordIndex,
    required this.isPlaying,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkMode ? Colors.white : Colors.black;
    final backgroundColor = darkMode ? Colors.black : Colors.white;

    Widget textWidget = SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.defaultTextPadding,
        vertical: MediaQuery.of(context).size.height * 0.4,
      ),
      child: Text(
        content,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          height: AppConstants.defaultLineHeight,
          letterSpacing: AppConstants.defaultLetterSpacing,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );

    // Apply mirror mode if enabled
    if (mirrorMode) {
      textWidget = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.14159), // 180 degrees
        child: textWidget,
      );
    }

    return Container(
      color: backgroundColor,
      child: textWidget,
    );
  }
}
