/// Fuzzy matching untuk correct universal OCR errors
/// Only supports common receipt keywords that appear on ANY receipt
class FuzzyMatcher {
  // Common UNIVERSAL receipt words - tidak ada brand/menu specific
  static const Map<String, String> _commonWords = {
    'SUBTOTAL': 'SUBTOTAL',
    'TOTAL': 'TOTAL',
    'DISCOUNT': 'DISCOUNT',
    'DISKON': 'DISKON',
    'SERVICE': 'SERVICE',
    'CHARGE': 'CHARGE',
    'PAYMENT': 'PAYMENT',
    'CASH': 'CASH',
    'CARD': 'CARD',
    'THANK': 'THANK',
    'TERIMA': 'TERIMA',
    'KASIH': 'KASIH',
    'INVOICE': 'INVOICE',
    'RECEIPT': 'RECEIPT',
    'TANGGAL': 'TANGGAL',
    'DATE': 'DATE',
    'TIME': 'TIME',
    'JAM': 'JAM',
  };

  /// Levenshtein distance untuk measure similarity
  static int levenshteinDistance(String s1, String s2) {
    s1 = s1.toUpperCase();
    s2 = s2.toUpperCase();

    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    final d = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) d[i][0] = i;
    for (int j = 0; j <= len2; j++) d[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,      // deletion
          d[i][j - 1] + 1,      // insertion
          d[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return d[len1][len2];
  }

  /// Match word ke closest common word jika similar enough
  static String? findClosestMatch(String word, {double threshold = 0.8}) {
    if (word.isEmpty) return null;

    String bestMatch = '';
    int bestDistance = word.length;

    for (final entry in _commonWords.entries) {
      final distance = levenshteinDistance(word, entry.key);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = entry.value;
      }
    }

    // Calculate similarity ratio
    final maxLen = word.length > bestMatch.length ? word.length : bestMatch.length;
    final similarity = 1.0 - (bestDistance / maxLen);

    return similarity >= threshold ? bestMatch : null;
  }

  /// Universal OCR error corrections (non-contextual)
  static String correctCommonErrors(String text) {
    var corrected = text;

    // Only universal character confusion - NO store/menu specific logic
    // These are generic digit/letter confusions in OCR:
    // - lowercase L (l) → uppercase I (I) 
    // - multiple spaces → single space
    // - trailing spaces → removed
    
    corrected = corrected.replaceAll(RegExp(r'\bl\b'), 'I'); // lowercase l word → I
    corrected = corrected.replaceAll(RegExp(r'\s{2,}'), ' '); // Multiple spaces → single
    corrected = corrected.trim(); // Remove leading/trailing spaces

    return corrected;
  }

  /// Analyze text quality/confidence
  static double analyzeQuality(String text) {
    if (text.isEmpty) return 0.0;

    double score = 1.0;
    final lines = text.split('\n');

    // Penalise fragmented text (too many short lines)
    final shortLines = lines.where((l) => l.trim().length < 4).length;
    if (shortLines > lines.length * 0.5) {
      score *= 0.7; // 30% penalty
    }

    // Penalise excessive whitespace/newlines
    if (text.contains(RegExp(r'\n\n+'))) {
      score *= 0.85;
    }

    // Penalise if too few meaningful lines
    if (lines.length < 3) {
      score *= 0.8;
    }

    return score.clamp(0.0, 1.0);
  }
}
