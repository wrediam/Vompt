import '../../core/constants/app_constants.dart';

class TextProcessor {
  // Clean text for speech matching
  static String cleanText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  // Tokenize text into words
  static List<String> tokenize(String text) {
    if (text.trim().isEmpty) return [];
    return cleanText(text).split(' ').where((word) => word.isNotEmpty).toList();
  }

  // Remove filler words
  static List<String> removeFillerWords(List<String> words) {
    return words
        .where((word) => !AppConstants.fillerWords.contains(word.toLowerCase()))
        .toList();
  }

  // Calculate similarity between two strings (simple Levenshtein-like)
  static double calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final aClean = cleanText(a);
    final bClean = cleanText(b);

    if (aClean == bClean) return 1.0;

    // Simple similarity: count matching characters
    int matches = 0;
    final minLength = aClean.length < bClean.length ? aClean.length : bClean.length;
    
    for (int i = 0; i < minLength; i++) {
      if (aClean[i] == bClean[i]) matches++;
    }

    return matches / (aClean.length > bClean.length ? aClean.length : bClean.length);
  }

  // Check if two words are similar enough (fuzzy match)
  static bool isSimilar(String word1, String word2, {double threshold = 0.7}) {
    return calculateSimilarity(word1, word2) >= threshold;
  }

  // Get word at position in text
  static String? getWordAtIndex(String text, int wordIndex) {
    final words = tokenize(text);
    if (wordIndex < 0 || wordIndex >= words.length) return null;
    return words[wordIndex];
  }

  // Get character position of word at index
  static int getCharacterPositionOfWord(String text, int wordIndex) {
    final words = text.split(RegExp(r'\s+'));
    if (wordIndex < 0 || wordIndex >= words.length) return 0;

    int position = 0;
    for (int i = 0; i < wordIndex; i++) {
      position += words[i].length + 1; // +1 for space
    }
    return position;
  }

  // Count words in text
  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  // Estimate reading time in minutes
  static double estimateReadingTime(String text, {int wordsPerMinute = 150}) {
    final wordCount = countWords(text);
    return wordCount / wordsPerMinute;
  }

  // Split text into lines for display
  static List<String> splitIntoLines(String text) {
    return text.split('\n');
  }

  // Get excerpt from text
  static String getExcerpt(String text, {int maxLength = 100}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
