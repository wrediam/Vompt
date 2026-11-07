/// Rebuilds a recognizer's running transcript from its events: finalized
/// text is permanent, and the volatile tail is replaced on every update.
class TranscriptAssembler {
  final List<String> _finalized = [];
  List<String> _volatile = const [];

  /// Finalized tokens followed by the current volatile tail.
  List<String> get tokens => [..._finalized, ..._volatile];

  void setVolatile(List<String> tokens) => _volatile = tokens;

  void addFinal(List<String> tokens) {
    _finalized.addAll(tokens);
    _volatile = const [];
  }

  void clear() {
    _finalized.clear();
    _volatile = const [];
  }
}
