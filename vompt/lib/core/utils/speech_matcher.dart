import 'text_processor.dart';

class SpeechMatcher {
  List<String> scriptWords = [];
  int currentIndex = 0;
  List<String> recentMatches = [];
  static const int maxRecentMatches = 5;

  SpeechMatcher(String scriptText) {
    scriptWords = TextProcessor.tokenize(scriptText);
  }

  // Update script text
  void updateScript(String scriptText) {
    scriptWords = TextProcessor.tokenize(scriptText);
    currentIndex = 0;
    recentMatches.clear();
  }

  // Find next match for spoken phrase
  int? findNextMatch(String spokenPhrase) {
    if (scriptWords.isEmpty || spokenPhrase.trim().isEmpty) return null;

    // Clean and tokenize spoken phrase
    final spokenWords = TextProcessor.removeFillerWords(
      TextProcessor.tokenize(spokenPhrase),
    );

    if (spokenWords.isEmpty) return null;

    // Try exact sequence match first
    final exactMatch = _findExactSequence(spokenWords);
    if (exactMatch != null) {
      _updatePosition(exactMatch, spokenWords.length);
      return exactMatch;
    }

    // Try fuzzy match
    final fuzzyMatch = _findFuzzyMatch(spokenWords);
    if (fuzzyMatch != null) {
      _updatePosition(fuzzyMatch, spokenWords.length);
      return fuzzyMatch;
    }

    // Try single word match near current position
    final nearbyMatch = _findNearbyMatch(spokenWords.first);
    if (nearbyMatch != null) {
      _updatePosition(nearbyMatch, 1);
      return nearbyMatch;
    }

    return null;
  }

  // Find exact sequence match
  int? _findExactSequence(List<String> spokenWords) {
    // Start searching from current position
    for (int i = currentIndex; i < scriptWords.length - spokenWords.length + 1; i++) {
      bool matches = true;
      for (int j = 0; j < spokenWords.length; j++) {
        if (scriptWords[i + j] != spokenWords[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return i;
    }

    // If not found ahead, search from beginning
    for (int i = 0; i < currentIndex && i < scriptWords.length - spokenWords.length + 1; i++) {
      bool matches = true;
      for (int j = 0; j < spokenWords.length; j++) {
        if (scriptWords[i + j] != spokenWords[j]) {
          matches = false;
          break;
        }
      }
      if (matches) return i;
    }

    return null;
  }

  // Find fuzzy match (allows some word variations)
  int? _findFuzzyMatch(List<String> spokenWords) {
    const double similarityThreshold = 0.7;
    int bestMatchIndex = -1;
    double bestScore = 0.0;

    // Search window around current position
    final searchStart = currentIndex > 50 ? currentIndex - 50 : 0;
    final searchEnd = currentIndex + 100 < scriptWords.length 
        ? currentIndex + 100 
        : scriptWords.length;

    for (int i = searchStart; i < searchEnd - spokenWords.length + 1; i++) {
      double score = 0.0;
      for (int j = 0; j < spokenWords.length; j++) {
        if (i + j < scriptWords.length) {
          score += TextProcessor.calculateSimilarity(
            spokenWords[j],
            scriptWords[i + j],
          );
        }
      }
      score /= spokenWords.length;

      if (score > bestScore && score >= similarityThreshold) {
        bestScore = score;
        bestMatchIndex = i;
      }
    }

    return bestMatchIndex >= 0 ? bestMatchIndex : null;
  }

  // Find match near current position
  int? _findNearbyMatch(String word) {
    // Search within 20 words of current position
    const searchWindow = 20;
    final searchStart = currentIndex > searchWindow ? currentIndex - searchWindow : 0;
    final searchEnd = currentIndex + searchWindow < scriptWords.length 
        ? currentIndex + searchWindow 
        : scriptWords.length;

    for (int i = searchStart; i < searchEnd; i++) {
      if (TextProcessor.isSimilar(word, scriptWords[i])) {
        return i;
      }
    }

    return null;
  }

  // Update current position
  void _updatePosition(int matchIndex, int matchLength) {
    currentIndex = matchIndex + matchLength;
    
    // Keep track of recent matches to detect patterns
    recentMatches.add(matchIndex.toString());
    if (recentMatches.length > maxRecentMatches) {
      recentMatches.removeAt(0);
    }
  }

  // Reset to beginning
  void reset() {
    currentIndex = 0;
    recentMatches.clear();
  }

  // Jump to specific position
  void jumpTo(int wordIndex) {
    if (wordIndex >= 0 && wordIndex < scriptWords.length) {
      currentIndex = wordIndex;
    }
  }

  // Get current word
  String? getCurrentWord() {
    if (currentIndex >= 0 && currentIndex < scriptWords.length) {
      return scriptWords[currentIndex];
    }
    return null;
  }

  // Get progress percentage
  double getProgress() {
    if (scriptWords.isEmpty) return 0.0;
    return (currentIndex / scriptWords.length) * 100;
  }

  // Check if at end
  bool isAtEnd() {
    return currentIndex >= scriptWords.length - 1;
  }
}
