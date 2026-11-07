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

  // Calculate similarity between two strings using Levenshtein distance
  static double calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final aClean = cleanText(a);
    final bClean = cleanText(b);

    if (aClean == bClean) return 1.0;

    final la = aClean.length;
    final lb = bClean.length;

    // Quick reject if lengths are very different
    if ((la - lb).abs() > 3) return 0.0;

    // Levenshtein distance via dynamic programming
    final d = List.generate(la + 1, (i) => List.filled(lb + 1, 0));
    for (int i = 0; i <= la; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= lb; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= la; i++) {
      for (int j = 1; j <= lb; j++) {
        final cost = aClean[i - 1] == bClean[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }

    final maxLen = la > lb ? la : lb;
    return 1.0 - (d[la][lb] / maxLen);
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
