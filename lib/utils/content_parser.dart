/// Parser für Content-Namen um Metadaten zu extrahieren
/// OPTIMIERT: Mit Memoization-Cache und vorkompilierten RegExp-Patterns
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
    '8K', '4320p',
    '4K', 'UHD', '2160p', '3840p', '3840P',
    'FHD', '1080p',
    'HD', '720p',
    'SD', '480p',
  ];

  /// Unicode/Sonderzeichen-Varianten von Qualitäts-Tags (werden zu 4K/HD normalisiert)
  static const Map<String, String> unicodeQualityTags = {
    'ᵁᴴᴰ': '4K',
    '🅄🅗🅓': '4K',
    'Ⓤⓗⓓ': '4K',
    'ⓊⒽⒹ': '4K',
    '⁴ᴷ': '4K',
    '⁴ᵏ': '4K',
    '⁴K': '4K',
    '⓸Ⓚ': '4K',
    '➍K': '4K',
    '₄K': '4K',
    '³⁸⁴⁰ᴾ': '4K',
    '³⁸⁴⁰ᵖ': '4K',
    '³⁸⁴⁰P': '4K',
    'ᴴᴰ': 'HD',
    'ᶠᴴᴰ': 'FHD',
  };

  /// Unicode-Tags die komplett entfernt werden sollen
  static const List<String> unicodeRemoveTags = [
    'ʰᵉᵛᶜ', 'ᴴᴱⱽᶜ', 'HEVC',
    'ʰ²⁶⁴', 'ᴴ²⁶⁴', 'H264', 'H.264',
    'ʰ²⁶⁵', 'ᴴ²⁶⁵', 'H265', 'H.265',
    'ᴿᴬᵂ', 'RAW',
    'ᴬᶜ³', 'AC3',
    'ᴬᴬᶜ', 'AAC',
    'ᴰᵀˢ', 'DTS',
  ];

  /// Ländercodes die als Badge angezeigt werden sollen
  static const Set<String> countryCodes = {
    'US', 'UK', 'DE', 'FR', 'ES', 'IT', 'NL', 'BE', 'AT', 'CH',
    'CA', 'AU', 'NZ', 'IE',
    'SE', 'NO', 'DK', 'FI', 'IS',
    'PL', 'CZ', 'HU', 'RO', 'BG', 'HR', 'RS', 'SI', 'BA', 'MK', 'AL', 'GR', 'CY', 'MT',
    'TR', 'RU', 'UA', 'BY', 'LT', 'LV', 'EE',
    'PT', 'BR', 'AR', 'MX', 'CO', 'VE', 'CL', 'PE',
    'IN', 'PK', 'TH', 'MY', 'SG', 'PH', 'VN', 'ID', 'JP', 'KR', 'CN', 'HK', 'TW',
    'IL', 'IR', 'SA', 'AE', 'EG', 'MA', 'ZA',
  };

  /// Bekannte "Hot/Popular" Tags
  static const List<String> popularTags = [
    'HOT', 'TOP', 'NEW', 'VIP', 'PREMIUM', 'BEST', 'POPULAR', 'TREND',
  ];

  /// Alle Präfix-Tags die am Anfang entfernt werden sollen
  static const List<String> prefixTags = [
    'HOT', 'TOP', 'NEW', 'VIP', 'PREMIUM', 'BEST', 'POPULAR', 'TREND', 'GOLD',
    'NF', 'NETFLIX', 'NFLX',
    'AMZN', 'AP', 'AMAZON', 'PRIME', 'AS',
    'DSNP', 'DP', 'DISNEY', 'DNY',
    'HMAX', 'HBO', 'MAX',
    'ATVP', 'ATV', 'APPLE',
    'PMTP', 'PARAMOUNT', 'PARA',
    'HULU', 'TUBI', 'VIX', 'WOW', 'NOW',
    'PCOK', 'PEACOCK',
    'SHO', 'SHOWTIME',
    'STAN', 'STARZ',
    'MUBI', 'CC', 'DCU',
    'SLING', 'JOYN', 'MEO', 'DSTV', 'SKYGO', 'GOBX', 'OSN',
    'PLAY', 'PLAY+', 'PLAYER', 'GO', 'SAT', 'DVB-T',
    'M+', 'V+', 'ZINA',
    '24/7', 'SPORTS', 'SPO', 'NBA', 'F1', 'SNOOKER', 'SPFL',
    'DO', 'DOC', 'DOCU', 'DOCUMENTARY',
    'MV', 'MOVIE', 'FILM', 'MOV',
    'TV', 'SERIES', 'SHOW', 'SER',
    'AN', 'ANIME', 'ANI',
    'KI', 'KIDS', 'KID',
    'OD', 'VO', 'VD', 'CITY',
    'US', 'UK', 'DE', 'FR', 'ES', 'IT', 'NL', 'BE', 'AT', 'CH',
    'CA', 'CA EN', 'CA FR', 'AU', 'NZ', 'IE', 'IRL',
    'SE', 'NO', 'DK', 'FI', 'IS',
    'PL', 'CZ', 'HU', 'RO', 'BG', 'HR', 'RS', 'SI', 'BA', 'MK', 'AL', 'GR', 'CY', 'MT',
    'TR', 'RU', 'UA', 'BY', 'LT', 'LV', 'EE',
    'PT', 'BR', 'AR', 'ARG', 'MX', 'CO', 'CHL', 'VE', 'UY', 'CR', 'HN', 'PR',
    'IN', 'IN-PREM', 'IN-BG', 'PK', 'PAK-PREM', 'PB-PREM', 'KN-PREM', 'TM-PREM',
    'TH', 'MY', 'SG', 'PH', 'VN', 'KH', 'ID',
    'JP', 'KR', 'CN', 'HK', 'TW',
    'IL', 'IR', 'SA', 'AE', 'BH', 'KW', 'QA', 'OM',
    'AF', 'AFG', 'AFR', 'EG', 'MA', 'TN', 'DZ', 'LY',
    'NG', 'NIG', 'GHA', 'KE', 'ZA', 'ETH', 'UGA', 'SEN', 'SOM',
    'LA', 'AZ', 'GE', 'AM', 'ARM', 'KZ', 'UZ',
    'AL-VIP', 'PL VIP', 'GR VIP', 'BE-VIP', 'TR VIP', 'BE-FR', 'DE GO', 'AR 4K',
    'EXYU', 'STC', 'CRB', 'MXC', 'YP', 'NM', 'CG', 'MG', 'TK', 'RK',
    'SU', 'TY', 'SS', 'TS', 'RX', 'RC', 'RD', 'TF', 'FL',
    'BAN', 'SRI', 'KU',
    'HINDI', 'TAMIL', 'PUNJABI', 'MALAYALAM', 'TELUGU', 'GUJARATI', 'KANNADA', 'MARATHI', 'BENGALI',
    'ENGLISH', 'GERMAN', 'FRENCH', 'SPANISH', 'ITALIAN', 'ARABIC', 'TURKISH', 'RUSSIAN', 'POLISH',
    'GER', 'ENG', 'MULTI',
    'F', 'M', 'SR',
  ];

  // ============== OPTIMIERUNG: Vorkompilierte Patterns ==============

  /// Cache für Parse-Ergebnisse (Memoization)
  static final Map<String, ContentMetadata> _parseCache = {};
  static const int _maxCacheSize = 20000;

  /// Vorkompilierte Regex-Patterns (einmal erstellen, oft verwenden)
  static final RegExp _countryPrefixPattern = RegExp(r'^([A-Z]{2})\s*:', caseSensitive: false);
  static final RegExp _yearPattern = RegExp(r'\b(19\d{2}|20\d{2})\b');
  static final RegExp _unicodeCleanPattern = RegExp(r'[\u00B2\u00B3\u00B9\u1D00-\u1D7F\u1D80-\u1DBF\u2070-\u209F\u02B0-\u02FF]+');
  static final RegExp _bracketsPattern = RegExp(r'\s*[\[\(][^\]\)]*[\]\)]\s*');
  static final RegExp _pipesPattern = RegExp(r'\s*\|[^|]+\|\s*');
  static final RegExp _multiSeparatorPattern = RegExp(r'[\s\-\–\—\|]{2,}');
  static final RegExp _leadingSeparatorPattern = RegExp(r'^[\s\-\–\—\|]+');
  static final RegExp _trailingSeparatorPattern = RegExp(r'[\s\-\–\—\|:]+$');
  static final RegExp _multiSpacePattern = RegExp(r'\s{2,}');

  /// Vorkompilierte Sprach-Patterns
  static final Map<String, RegExp> _languagePatterns = {
    for (final key in languageCodes.keys)
      key: RegExp(
        r'(?:^|\s|\||\[|\()' + key + r'(?:\s|\||:|\-|\–|\—|\]|\)|$)',
        caseSensitive: false,
      )
  };

  /// Vorkompilierte Qualitäts-Patterns
  static final Map<String, RegExp> _qualityPatterns = {
    for (final q in qualityTags)
      q: RegExp(r'(?:^|\b)' + q + r'(?:\b|:)', caseSensitive: false)
  };

  /// Vorkompilierte Popular-Patterns (nur Präfix mit Trennzeichen)
  static final Map<String, RegExp> _popularPatterns = {
    for (final tag in popularTags)
      tag: RegExp('^$tag' r'\s*[\-\–\—\|]', caseSensitive: false)
  };

  /// Vorkompilierte Präfix-Patterns (sortiert nach Länge, längste zuerst)
  static final List<MapEntry<String, RegExp>> _prefixPatterns = () {
    final sorted = List<String>.from(prefixTags)..sort((a, b) => b.length.compareTo(a.length));
    return sorted.map((tag) {
      final escaped = RegExp.escape(tag);
      return MapEntry(tag, RegExp('^$escaped' r'\s*[\-\–\—\|:]+\s*', caseSensitive: false));
    }).toList();
  }();

  /// Vorkompilierte Qualitäts-Entfernungs-Patterns
  static final Map<String, List<RegExp>> _qualityRemovePatterns = {
    for (final q in qualityTags)
      q: [
        RegExp('^$q' r'\s*:\s*', caseSensitive: false),
        RegExp(r'(?:^|\s)' + q + r'(?:\s*[\-\–\—\|:]\s*|\s+|$)', caseSensitive: false),
        RegExp(r'\s+' + q + r'$', caseSensitive: false),
      ]
  };

  /// Vorkompilierte Popular-Entfernungs-Patterns
  static final Map<String, List<RegExp>> _popularRemovePatterns = {
    for (final tag in popularTags)
      tag: [
        RegExp('^$tag' r'\s*[\-\–\—\|:]+\s*', caseSensitive: false),
        RegExp(r'\s*[\-\–\—\|:]+\s*' + tag + r'$', caseSensitive: false),
      ]
  };

  /// Cache leeren (bei Speicherknappheit oder App-Neustart)
  static void clearCache() {
    _parseCache.clear();
  }

  /// Schneller Check ob ein Name "popular" ist (ohne volles Parsing)
  static bool isPopularQuick(String name) {
    final upper = name.toUpperCase();
    for (final tag in popularTags) {
      if (upper.startsWith(tag)) {
        // Prüfe ob echtes Präfix mit Trennzeichen
        final afterTag = upper.substring(tag.length).trimLeft();
        if (afterTag.isNotEmpty && '-–—|:'.contains(afterTag[0])) {
          return true;
        }
      }
    }
    return false;
  }

  /// Schneller Check für Qualität (ohne volles Parsing)
  static String? getQualityQuick(String name) {
    // Unicode zuerst
    for (final entry in unicodeQualityTags.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    // Dann normale Tags (Case-insensitive über toUpperCase)
    final upper = name.toUpperCase();
    if (upper.contains('8K') || upper.contains('4320P')) return '8K';
    if (upper.contains('4K') || upper.contains('UHD') || upper.contains('2160P') || upper.contains('3840P')) return '4K';
    if (upper.contains('FHD') || upper.contains('1080P')) return 'FHD';
    if (upper.contains('HD') || upper.contains('720P')) return 'HD';
    return null;
  }

  /// Schneller Check für Sprache (ohne volles Parsing)
  static String? getLanguageQuick(String name) {
    final upper = name.toUpperCase();
    // Häufigste Sprachen zuerst prüfen
    if (upper.contains('GERMAN') || _containsTag(upper, 'DE') || _containsTag(upper, 'GER')) return 'DE';
    if (upper.contains('ENGLISH') || _containsTag(upper, 'EN') || _containsTag(upper, 'ENG')) return 'EN';
    if (_containsTag(upper, 'FR') || upper.contains('FRENCH')) return 'FR';
    if (_containsTag(upper, 'ES') || upper.contains('SPANISH')) return 'ES';
    if (_containsTag(upper, 'IT') || upper.contains('ITALIAN')) return 'IT';
    if (_containsTag(upper, 'TR') || upper.contains('TURKISH')) return 'TR';
    return null;
  }

  /// Schneller Check für Land (ohne volles Parsing)
  static String? getCountryQuick(String name) {
    // Nur Präfix mit Doppelpunkt
    final match = _countryPrefixPattern.firstMatch(name);
    if (match != null) {
      final code = match.group(1)!.toUpperCase();
      if (countryCodes.contains(code)) return code;
    }
    return null;
  }

  /// Hilfsfunktion: Prüft ob Tag als separates Wort vorkommt
  static bool _containsTag(String upper, String tag) {
    final index = upper.indexOf(tag);
    if (index == -1) return false;
    // Prüfe ob echtes Tag (nicht Teil eines Wortes)
    final before = index > 0 ? upper[index - 1] : ' ';
    final after = index + tag.length < upper.length ? upper[index + tag.length] : ' ';
    return !RegExp(r'[A-Z0-9]').hasMatch(before) && !RegExp(r'[A-Z0-9]').hasMatch(after);
  }

  /// Extrahiert Metadaten aus einem Content-Namen (mit Caching)
  static ContentMetadata parse(String name) {
    // Cache-Lookup
    final cached = _parseCache[name];
    if (cached != null) return cached;

    // Eigentliches Parsing
    final result = _parseInternal(name);

    // Cache speichern (mit Größenlimit)
    if (_parseCache.length >= _maxCacheSize) {
      // Entferne älteste 20% der Einträge
      final keysToRemove = _parseCache.keys.take(_maxCacheSize ~/ 5).toList();
      for (final key in keysToRemove) {
        _parseCache.remove(key);
      }
    }
    _parseCache[name] = result;

    return result;
  }

  /// Internes Parsing (ohne Cache)
  static ContentMetadata _parseInternal(String name) {
    String cleanName = name;
    String? language;
    String? quality;
    String? country;
    bool isPopular = false;
    final tags = <String>[];

    // Ländercode aus Präfix extrahieren
    final countryMatch = _countryPrefixPattern.firstMatch(name);
    if (countryMatch != null) {
      final code = countryMatch.group(1)!.toUpperCase();
      if (countryCodes.contains(code)) {
        country = code;
      }
    }

    // Sprache erkennen (mit vorkompilierten Patterns)
    for (final entry in _languagePatterns.entries) {
      if (entry.value.hasMatch(name)) {
        language = entry.key;
        break;
      }
    }

    // Qualität erkennen
    // 1. Zuerst Unicode-Varianten
    for (final entry in unicodeQualityTags.entries) {
      if (name.contains(entry.key)) {
        quality = entry.value;
        break;
      }
    }
    // 2. Dann normale Tags
    if (quality == null) {
      for (final entry in _qualityPatterns.entries) {
        if (entry.value.hasMatch(name)) {
          quality = entry.key.toUpperCase();
          break;
        }
      }
    }
    // 3. Normalisieren
    if (quality == 'UHD' || quality == '2160P' || quality == '3840P') {
      quality = '4K';
    } else if (quality == '4320P') {
      quality = '8K';
    }

    // Jahr erkennen
    int? year;
    final yearMatch = _yearPattern.firstMatch(name);
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(1)!);
    }

    // Popular Tags erkennen
    for (final entry in _popularPatterns.entries) {
      if (entry.value.hasMatch(name)) {
        isPopular = true;
        tags.add(entry.key);
        break;
      }
    }

    // === BEREINIGUNG ===

    // 0. Unicode-Sonderzeichen entfernen
    cleanName = cleanName.replaceAll(_unicodeCleanPattern, ' ').trim();

    // 1. Qualitäts-Tags entfernen
    for (final patterns in _qualityRemovePatterns.values) {
      for (final pattern in patterns) {
        cleanName = cleanName.replaceAll(pattern, ' ');
      }
    }
    cleanName = cleanName.trim();

    // 2. Präfix-Tags entfernen (iterativ)
    bool foundPrefix = true;
    int iterations = 0;
    while (foundPrefix && iterations < 10) {
      foundPrefix = false;
      iterations++;
      for (final entry in _prefixPatterns) {
        if (entry.value.hasMatch(cleanName)) {
          cleanName = cleanName.replaceFirst(entry.value, '').trim();
          foundPrefix = true;
          break;
        }
      }
    }

    // 3. Popular-Tags entfernen
    for (final patterns in _popularRemovePatterns.values) {
      for (final pattern in patterns) {
        cleanName = cleanName.replaceAll(pattern, '');
      }
    }

    // 4. Tags in Klammern entfernen
    cleanName = cleanName.replaceAll(_bracketsPattern, ' ');

    // 5. Tags zwischen Pipes entfernen
    cleanName = cleanName.replaceAll(_pipesPattern, ' ');

    // 6. Aufräumen
    cleanName = cleanName
        .replaceAll(_multiSeparatorPattern, ' ')
        .replaceAll(_leadingSeparatorPattern, '')
        .replaceAll(_trailingSeparatorPattern, '')
        .replaceAll(_multiSpacePattern, ' ')
        .trim();

    // Jahr aus cleanName entfernen
    if (year != null) {
      cleanName = cleanName
          .replaceAll(RegExp(r'\s*[\(\[]?' + year.toString() + r'[\)\]]?\s*'), ' ')
          .replaceAll(_multiSpacePattern, ' ')
          .trim();
    }

    return ContentMetadata(
      originalName: name,
      cleanName: cleanName.isEmpty ? name : cleanName,
      language: language,
      languageDisplayName: language != null ? languageCodes[language] : null,
      quality: quality,
      country: country,
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

      if (preferredLanguage != null) {
        final aMatch = metaA.language == preferredLanguage.toUpperCase();
        final bMatch = metaB.language == preferredLanguage.toUpperCase();
        if (aMatch && !bMatch) return -1;
        if (!aMatch && bMatch) return 1;
      }

      if (metaA.isPopular && !metaB.isPopular) return -1;
      if (!metaA.isPopular && metaB.isPopular) return 1;

      final qualityOrder = {'4K': 0, 'UHD': 0, '2160p': 0, 'FHD': 1, '1080p': 1, 'HD': 2, '720p': 2, 'SD': 3, '480p': 3};
      final qA = qualityOrder[metaA.quality] ?? 99;
      final qB = qualityOrder[metaB.quality] ?? 99;
      if (qA != qB) return qA.compareTo(qB);

      return 0;
    });
  }

  /// Holt alle Inhalte mit einem bestimmten Tag
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
  final String? country;
  final int? year;
  final bool isPopular;
  final List<String> tags;

  ContentMetadata({
    required this.originalName,
    required this.cleanName,
    this.language,
    this.languageDisplayName,
    this.quality,
    this.country,
    this.year,
    this.isPopular = false,
    this.tags = const [],
  });

  @override
  String toString() {
    return 'ContentMetadata(cleanName: $cleanName, language: $language, quality: $quality, country: $country, isPopular: $isPopular, tags: $tags)';
  }
}
