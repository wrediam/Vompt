import 'package:flutter/widgets.dart';

/// Keeps text-heavy screens to a comfortable line length on iPad.
class ReadableWidth extends StatelessWidget {
  static const maxWidth = 760.0;
  final Widget child;
  const ReadableWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
