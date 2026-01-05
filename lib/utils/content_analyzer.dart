import 'package:flutter/foundation.dart';

/// Analysiert Content-Namen und extrahiert Metadaten
class ContentAnalyzer {
  /// Analysiert eine Liste von Namen und gibt Statistiken zurück
  static void analyzeNames(List<String> names, {String category = 'Content'}) {
    final patterns = <String, int>{};
    final languages = <String, int>{};
    final prefixes = <String, int>{};

    // Regex für verschiedene Muster
    final tagRegex = RegExp(r'\[([^\]]+)\]|\|([^|]+)\||^([A-Z]{2,3})\s*[\|:\-]');
    final langRegex = RegExp(r'\b(DE|EN|FR|ES|IT|TR|AR|RU|PL|NL|PT|GR|HR|RS|HU|CZ|RO|BG|UA|MULTI|GERMAN|ENGLISH|FRENCH|SPANISH|TURKISH|ARABIC)\b', caseSensitive: false);
    final qualityRegex = RegExp(r'\b(HD|FHD|UHD|4K|720p|1080p|2160p|SD)\b', caseSensitive: false);
    final specialRegex = RegExp(r'\b(HOT|TOP|NEW|VIP|PREMIUM|BEST|POPULAR)\b', caseSensitive: false);

    for (final name in names) {
      // Tags finden
      for (final match in tagRegex.allMatches(name)) {
        final tag = match.group(1) ?? match.group(2) ?? match.group(3);
        if (tag != null) {
          patterns[tag] = (patterns[tag] ?? 0) + 1;
        }
      }

      // Sprachen finden
      for (final match in langRegex.allMatches(name)) {
        final lang = match.group(0)?.toUpperCase();
        if (lang != null) {
          languages[lang] = (languages[lang] ?? 0) + 1;
        }
      }

      // Qualität finden
      for (final match in qualityRegex.allMatches(name)) {
        final quality = match.group(0)?.toUpperCase();
        if (quality != null) {
          patterns['QUALITY:$quality'] = (patterns['QUALITY:$quality'] ?? 0) + 1;
        }
      }

      // Spezielle Tags finden
      for (final match in specialRegex.allMatches(name)) {
        final special = match.group(0)?.toUpperCase();
        if (special != null) {
          patterns['SPECIAL:$special'] = (patterns['SPECIAL:$special'] ?? 0) + 1;
        }
      }

      // Prefix vor dem ersten | oder : oder -
      final prefixMatch = RegExp(r'^([A-Z]{2,3})\s*[\|:\-]').firstMatch(name);
      if (prefixMatch != null) {
        final prefix = prefixMatch.group(1);
        if (prefix != null) {
          prefixes[prefix] = (prefixes[prefix] ?? 0) + 1;
        }
      }
    }

    // Sortieren nach Häufigkeit
    final sortedPatterns = patterns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedLanguages = languages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedPrefixes = prefixes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    debugPrint('=== $category Analysis (${names.length} items) ===');
    debugPrint('');
    debugPrint('Top 20 Patterns:');
    for (final entry in sortedPatterns.take(20)) {
      debugPrint('  ${entry.key}: ${entry.value}');
    }
    debugPrint('');
    debugPrint('Languages found:');
    for (final entry in sortedLanguages) {
      debugPrint('  ${entry.key}: ${entry.value}');
    }
    debugPrint('');
    debugPrint('Prefixes found:');
    for (final entry in sortedPrefixes.take(15)) {
      debugPrint('  ${entry.key}: ${entry.value}');
    }
    debugPrint('');

    // Beispiele ausgeben
    debugPrint('Sample names (first 10):');
    for (final name in names.take(10)) {
      debugPrint('  $name');
    }
    debugPrint('=====================================');
  }

  /// Zeigt einige zufällige Namen zur Analyse
  static void showRandomSamples(List<String> names, {int count = 30}) {
    final shuffled = List<String>.from(names)..shuffle();
    debugPrint('=== Random Samples ($count of ${names.length}) ===');
    for (final name in shuffled.take(count)) {
      debugPrint('  $name');
    }
    debugPrint('=====================================');
  }
}
