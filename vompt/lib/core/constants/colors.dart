import 'package:material_ui/material_ui.dart';

/// Vompt's palette, borrowed from the broadcast studio.
///
/// Color always carries meaning here: tally red means the mic is live,
/// cue amber marks where the reader is. Neither is used as decoration.
class AppColors {
  /// Deep navy, nearly black: the studio after dark. App surfaces.
  static const Color ink = Color(0xFF0D111C);

  /// Raised surfaces: sheets, fields, menus.
  static const Color raised = Color(0xFF161B29);

  /// A step above raised: pressed rows, selected items, inputs on sheets.
  static const Color raisedHigh = Color(0xFF1E2434);

  /// Hairlines and quiet borders.
  static const Color line = Color(0xFF2A3143);

  /// Reading text: a warm white that is easier on the eyes than #FFF.
  static const Color paper = Color(0xFFF2EFE8);

  /// Secondary text and inactive icons (about 6.4:1 on ink).
  static const Color muted = Color(0xFF8F97AA);

  /// Tally light: the mic is listening.
  static const Color tally = Color(0xFFF2493B);

  /// Cue light: the word being read, and the primary action.
  static const Color cue = Color(0xFFFFC24A);

  /// Text on a cue-colored surface.
  static const Color onCue = Color(0xFF1C1607);

  /// Good outcomes in stats (on pace, clean take).
  static const Color good = Color(0xFF6FCF97);

  /// The prompter itself is pure black: required for beam-splitter glass.
  static const Color prompter = Color(0xFF000000);

  // Kept for stored settings written by earlier versions.
  static const Color lightHighlight = Color(0xFFFFD700);
}
