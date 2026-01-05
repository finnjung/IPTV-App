/// Parser für Content-Namen um Metadaten zu extrahieren
class ContentParser {
  /// Bekannte Sprach-Codes
  static const Map<String, String> languageCodes = {
    'DE': 'Deutsch',
    'GERMAN': 'Deutsch',
    'GER': 'Deutsch',
    'EN': 'English',
    'ENGLISH': 'English',
    'ENG': 'English',
    'FR': 'Français',
    'FRENCH': 'Français',
    'ES': 'Español',
    'SPANISH': 'Español',
    'IT': 'Italiano',
    'ITALIAN': 'Italiano',
    'TR': 'Türkçe',
    'TURKISH': 'Türkçe',
    'AR': 'العربية',
    'ARABIC': 'العربية',
    'RU': 'Русский',
    'RUSSIAN': 'Русский',
    'PL': 'Polski',
    'POLISH': 'Polski',
    'NL': 'Nederlands',
    'DUTCH': 'Nederlands',
    'PT': 'Português',
    'PORTUGUESE': 'Português',
    'GR': 'Ελληνικά',
    'GREEK': 'Ελληνικά',
    'HR': 'Hrvatski',
    'RS': 'Српски',
    'HU': 'Magyar',
    'CZ': 'Čeština',
    'RO': 'Română',
    'BG': 'Български',
    'UA': 'Українська',
    'MULTI': 'Multi',
  };

  /// Bekannte Qualitäts-Tags
  static const List<String> qualityTags = [
    '4K', 'UHD', '2160p',
    'FHD', '1080p',
    'HD', '720p',
    'SD', '480p',
  ];

  /// Bekannte "Hot/Popular" Tags (für Badge-Erkennung)
  static const List<String> popularTags = [
    'HOT', 'TOP', 'NEW', 'VIP', 'PREMIUM', 'BEST', 'POPULAR', 'TREND',
  ];

  /// Alle Präfix-Tags die am Anfang entfernt werden sollen
  static const List<String> prefixTags = [
    // Popular/Special (nur wenn mit Trennzeichen, nicht "Top Gun")
    'HOT', 'TOP', 'NEW', 'VIP', 'PREMIUM', 'BEST', 'POPULAR', 'TREND',
    // Streaming-Dienste
    'NF', 'NETFLIX', 'NFLX',
    'AMZN', 'AP', 'AMAZON', 'PRIME', 'AS',
    'DSNP', 'DP', 'DISNEY', 'DNY',
    'HMAX', 'HBO', 'MAX',
    'ATVP', 'ATV', 'APPLE',
    'PMTP', 'PARAMOUNT', 'PARA',
    'HULU',
    'PCOK', 'PEACOCK',
    'SHO', 'SHOWTIME',
    'STAN', 'STARZ',
    'MUBI', 'CC', 'DCU',
    // Kategorien
    'DO', 'DOC', 'DOCU', 'DOCUMENTARY',
    'MV', 'MOVIE', 'FILM', 'MOV',
    'TV', 'SERIES', 'SHOW', 'SER',
    'AN', 'ANIME', 'ANI',
    'KI', 'KIDS', 'KID',
    // Sprachen (werden auch als Präfix entfernt)
    'DE', 'EN', 'FR', 'ES', 'IT', 'TR', 'AR', 'RU', 'PL', 'NL', 'PT', 'GR',
    'HR', 'RS', 'HU', 'CZ', 'RO', 'BG', 'UA', 'MULTI',
    'GER', 'ENG', 'GERMAN', 'ENGLISH', 'FRENCH', 'SPANISH', 'ITALIAN',
  ];

  // Regex-Pattern für Trennzeichen zwischen Tags (inkl. Unicode-Dashes)
  // Muss mindestens ein echtes Trennzeichen enthalten (-, –, —, |), nicht nur Leerzeichen
  static final _separatorPattern = r'\s*[\-\–\—\|]+\s*';

  /// Extrahiert Metadaten aus einem Content-Namen
  static ContentMetadata parse(String name) {
    String cleanName = name;
    String? language;
    String? quality;
    bool isPopular = false;
    final tags = <String>[];

    // Sprache erkennen (aus original Name)
    for (final entry in languageCodes.entries) {
      final pattern = RegExp(
        r'(?:^|\s|\||\[|\()' + entry.key + r'(?:\s|\||:|\-|\–|\—|\]|\)|$)',
        caseSensitive: false,
      );
      if (pattern.hasMatch(name)) {
        language = entry.key;
        break;
      }
    }

    // Qualität erkennen (aus original Name)
    for (final q in qualityTags) {
      final pattern = RegExp(r'\b' + q + r'\b', caseSensitive: false);
      if (pattern.hasMatch(name)) {
        quality = q.toUpperCase();
        break;
      }
    }

    // Jahr erkennen (4-stellige Zahl zwischen 1900-2099)
    int? year;
    final yearPattern = RegExp(r'\b(19\d{2}|20\d{2})\b');
    final yearMatch = yearPattern.firstMatch(name);
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(1)!);
    }

    // Popular Tags erkennen (nur als Präfix mit Trennzeichen, nicht "Top Gun")
    for (final tag in popularTags) {
      // Nur wenn am Anfang mit Trennzeichen danach
      final pattern = RegExp(
        '^' + tag + r'\s*[\-\–\—\|]',
        caseSensitive: false,
      );
      if (pattern.hasMatch(name)) {
        isPopular = true;
        tags.add(tag);
        break; // Ein Tag reicht
      }
    }

    // === BEREINIGUNG ===

    // 1. ZUERST Qualitäts-Tags entfernen (4K, HD, etc.)
    // Diese können überall stehen und blockieren sonst die Prefix-Erkennung
    for (final q in qualityTags) {
      // Als eigenständiges Tag mit Leerzeichen/Trennzeichen drumherum
      cleanName = cleanName.replaceAll(
        RegExp(r'(?:^|\s)' + q + r'(?:\s*[\-\–\—\|]\s*|\s+|$)', caseSensitive: false),
        ' ',
      );
    }
    cleanName = cleanName.trim();

    // 2. Präfix-Tags am Anfang entfernen (iterativ, auch mehrere hintereinander)
    bool foundPrefix = true;
    int iterations = 0;
    while (foundPrefix && iterations < 10) {
      foundPrefix = false;
      iterations++;

      for (final tag in prefixTags) {
        // Pattern: Tag am Anfang, gefolgt von Trennzeichen
        final pattern = RegExp(
          '^' + RegExp.escape(tag) + _separatorPattern,
          caseSensitive: false,
        );

        if (pattern.hasMatch(cleanName)) {
          cleanName = cleanName.replaceFirst(pattern, '');
          foundPrefix = true;
          break;
        }
      }
    }

    // 3. Popular-Tags entfernen (nur am Anfang/Ende mit Trennzeichen)
    for (final tag in popularTags) {
      cleanName = cleanName.replaceAll(
        RegExp('^' + tag + _separatorPattern, caseSensitive: false),
        '',
      );
      cleanName = cleanName.replaceAll(
        RegExp(_separatorPattern + tag + r'$', caseSensitive: false),
        '',
      );
    }

    // 4. Tags in Klammern entfernen: [TAG] oder (TAG)
    cleanName = cleanName.replaceAll(
      RegExp(r'\s*[\[\(][^\]\)]*[\]\)]\s*'),
      ' ',
    );

    // 5. Tags zwischen Pipes entfernen: |TAG|
    cleanName = cleanName.replaceAll(
      RegExp(r'\s*\|[^|]+\|\s*'),
      ' ',
    );

    // 6. Aufräumen (Doppelpunkte bleiben erhalten - gehören oft zum Titel)
    cleanName = cleanName
        // Mehrfache Trennzeichen (ohne Doppelpunkt) durch ein Leerzeichen
        .replaceAll(RegExp(r'[\s\-\–\—\|]{2,}'), ' ')
        // Trennzeichen am Anfang entfernen (ohne Doppelpunkt)
        .replaceAll(RegExp(r'^[\s\-\–\—\|]+'), '')
        // Trennzeichen am Ende entfernen (inkl. Doppelpunkt am Ende)
        .replaceAll(RegExp(r'[\s\-\–\—\|:]+$'), '')
        // Mehrfache Leerzeichen
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Jahr aus cleanName entfernen (wenn erkannt)
    if (year != null) {
      cleanName = cleanName
          .replaceAll(RegExp(r'\s*[\(\[]?' + year.toString() + r'[\)\]]?\s*'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }

    return ContentMetadata(
      originalName: name,
      cleanName: cleanName.isEmpty ? name : cleanName,
      language: language,
      languageDisplayName: language != null ? languageCodes[language] : null,
      quality: quality,
      year: year,
      isPopular: isPopular,
      tags: tags,
    );
  }

  /// Filtert eine Liste nach Sprache
  static List<T> filterByLanguage<T>(
    List<T> items,
    String languageCode,
    String Function(T) getName,
  ) {
    return items.where((item) {
      final meta = parse(getName(item));
      return meta.language == languageCode.toUpperCase();
    }).toList();
  }

  /// Sortiert eine Liste - bevorzugte Sprache zuerst, dann beliebte
  static List<T> sortByPreference<T>(
    List<T> items,
    String? preferredLanguage,
    String Function(T) getName,
  ) {
    return List<T>.from(items)..sort((a, b) {
      final metaA = parse(getName(a));
      final metaB = parse(getName(b));

      // Bevorzugte Sprache zuerst
      if (preferredLanguage != null) {
        final aMatch = metaA.language == preferredLanguage.toUpperCase();
        final bMatch = metaB.language == preferredLanguage.toUpperCase();
        if (aMatch && !bMatch) return -1;
        if (!aMatch && bMatch) return 1;
      }

      // Dann beliebte Inhalte
      if (metaA.isPopular && !metaB.isPopular) return -1;
      if (!metaA.isPopular && metaB.isPopular) return 1;

      // Dann nach Qualität (höher = besser)
      final qualityOrder = {'4K': 0, 'UHD': 0, '2160p': 0, 'FHD': 1, '1080p': 1, 'HD': 2, '720p': 2, 'SD': 3, '480p': 3};
      final qA = qualityOrder[metaA.quality] ?? 99;
      final qB = qualityOrder[metaB.quality] ?? 99;
      if (qA != qB) return qA.compareTo(qB);

      return 0;
    });
  }

  /// Holt alle Inhalte mit einem bestimmten Tag (HOT, TOP, etc.)
  static List<T> getPopular<T>(
    List<T> items,
    String Function(T) getName,
  ) {
    return items.where((item) {
      final meta = parse(getName(item));
      return meta.isPopular;
    }).toList();
  }
}

/// Metadaten eines Content-Elements
class ContentMetadata {
  final String originalName;
  final String cleanName;
  final String? language;
  final String? languageDisplayName;
  final String? quality;
  final int? year;
  final bool isPopular;
  final List<String> tags;

  ContentMetadata({
    required this.originalName,
    required this.cleanName,
    this.language,
    this.languageDisplayName,
    this.quality,
    this.year,
    this.isPopular = false,
    this.tags = const [],
  });

  @override
  String toString() {
    return 'ContentMetadata(cleanName: $cleanName, language: $language, quality: $quality, isPopular: $isPopular, tags: $tags)';
  }
}
