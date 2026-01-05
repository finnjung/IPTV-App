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
    '8K', '4320p',
    '4K', 'UHD', '2160p', '3840p', '3840P',
    'FHD', '1080p',
    'HD', '720p',
    'SD', '480p',
  ];

  /// Unicode/Sonderzeichen-Varianten von Qualitäts-Tags (werden zu 4K/HD normalisiert)
  static const Map<String, String> unicodeQualityTags = {
    // UHD Varianten → 4K
    'ᵁᴴᴰ': '4K',
    '🅄🅗🅓': '4K',
    'Ⓤⓗⓓ': '4K',
    'ⓊⒽⒹ': '4K',
    // 4K Varianten
    '⁴ᴷ': '4K',
    '⁴ᵏ': '4K',
    '⁴K': '4K',
    '⓸Ⓚ': '4K',
    '➍K': '4K',
    '₄K': '4K',
    // 3840P Varianten → 4K
    '³⁸⁴⁰ᴾ': '4K',
    '³⁸⁴⁰ᵖ': '4K',
    '³⁸⁴⁰P': '4K',
    // HD Varianten
    'ᴴᴰ': 'HD',
    'ᶠᴴᴰ': 'FHD',
  };

  /// Unicode-Tags die komplett entfernt werden sollen (kein Badge, nur Bereinigung)
  static const List<String> unicodeRemoveTags = [
    // Codec-Infos
    'ʰᵉᵛᶜ', 'ᴴᴱⱽᶜ', 'HEVC',
    'ʰ²⁶⁴', 'ᴴ²⁶⁴', 'H264', 'H.264',
    'ʰ²⁶⁵', 'ᴴ²⁶⁵', 'H265', 'H.265',
    // RAW Tag
    'ᴿᴬᵂ', 'RAW',
    // Andere technische Tags
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

  /// Bekannte "Hot/Popular" Tags (für Badge-Erkennung)
  static const List<String> popularTags = [
    'HOT', 'TOP', 'NEW', 'VIP', 'PREMIUM', 'BEST', 'POPULAR', 'TREND',
  ];

  /// Alle Präfix-Tags die am Anfang entfernt werden sollen
  static const List<String> prefixTags = [
    // Popular/Special (nur wenn mit Trennzeichen, nicht "Top Gun")
    'HOT', 'TOP', 'NEW', 'VIP', 'PREMIUM', 'BEST', 'POPULAR', 'TREND', 'GOLD',

    // Streaming-Dienste & Provider
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

    // Sport
    '24/7', 'SPORTS', 'SPO', 'NBA', 'F1', 'SNOOKER', 'SPFL',

    // Kategorien
    'DO', 'DOC', 'DOCU', 'DOCUMENTARY',
    'MV', 'MOVIE', 'FILM', 'MOV',
    'TV', 'SERIES', 'SHOW', 'SER',
    'AN', 'ANIME', 'ANI',
    'KI', 'KIDS', 'KID',
    'OD', 'VO', 'VD', 'CITY',

    // Ländercodes (ISO + erweitert)
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

    // VIP/Premium Varianten
    'AL-VIP', 'PL VIP', 'GR VIP', 'BE-VIP', 'TR VIP', 'BE-FR', 'DE GO', 'AR 4K',
    'EXYU', 'STC', 'CRB', 'MXC', 'YP', 'NM', 'CG', 'MG', 'TK', 'RK',
    'SU', 'TY', 'SS', 'TS', 'RX', 'RC', 'RD', 'TF', 'FL',
    'BAN', 'SRI', 'KU',

    // Sprachen (als Text)
    'HINDI', 'TAMIL', 'PUNJABI', 'MALAYALAM', 'TELUGU', 'GUJARATI', 'KANNADA', 'MARATHI', 'BENGALI',
    'ENGLISH', 'GERMAN', 'FRENCH', 'SPANISH', 'ITALIAN', 'ARABIC', 'TURKISH', 'RUSSIAN', 'POLISH',
    'GER', 'ENG', 'MULTI',

    // Sonstige
    'F', 'M', 'SR',
  ];

  // Regex-Pattern für Trennzeichen zwischen Tags (inkl. Unicode-Dashes und Doppelpunkt)
  // Muss mindestens ein echtes Trennzeichen enthalten (-, –, —, |, :), nicht nur Leerzeichen
  static final _separatorPattern = r'\s*[\-\–\—\|:]+\s*';

  /// Extrahiert Metadaten aus einem Content-Namen
  static ContentMetadata parse(String name) {
    String cleanName = name;
    String? language;
    String? quality;
    String? country;
    bool isPopular = false;
    final tags = <String>[];

    // Ländercode aus Präfix extrahieren (z.B. "DE:" → "DE")
    final countryMatch = RegExp(r'^([A-Z]{2})\s*:', caseSensitive: false).firstMatch(name);
    if (countryMatch != null) {
      final code = countryMatch.group(1)!.toUpperCase();
      if (countryCodes.contains(code)) {
        country = code;
      }
    }

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
    // 1. Zuerst Unicode-Varianten prüfen (ᵁᴴᴰ, ⁴ᴷ, etc.)
    for (final entry in unicodeQualityTags.entries) {
      if (name.contains(entry.key)) {
        quality = entry.value;
        break;
      }
    }
    // 2. Dann normale Qualitäts-Tags (4K:, HD, etc.)
    if (quality == null) {
      for (final q in qualityTags) {
        final pattern = RegExp(r'(?:^|\b)' + q + r'(?:\b|:)', caseSensitive: false);
        if (pattern.hasMatch(name)) {
          quality = q.toUpperCase();
          break;
        }
      }
    }
    // 3. Normalisiere Qualität: UHD, 2160p, 3840p → 4K | 4320p → 8K
    if (quality == 'UHD' || quality == '2160P' || quality == '3840P') {
      quality = '4K';
    } else if (quality == '4320P') {
      quality = '8K';
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

    // 0. Alle kleinen Unicode-Sonderzeichen entfernen (ᵁᴴᴰ, ᴾᴸ, ʰᵉᵛᶜ, ³⁸⁴⁰, etc.)
    // Entfernt: Superscript (inkl. ¹²³), Subscript, Modifier Letters, etc.
    cleanName = cleanName.replaceAll(
      RegExp(r'[\u00B2\u00B3\u00B9\u1D00-\u1D7F\u1D80-\u1DBF\u2070-\u209F\u02B0-\u02FF]+'),
      ' ',
    );
    cleanName = cleanName.trim();

    // 1. ZUERST Qualitäts-Tags entfernen (4K, HD, 3840P, etc.)
    // Diese können überall stehen und blockieren sonst die Prefix-Erkennung
    for (final q in qualityTags) {
      // Als Präfix mit Doppelpunkt (z.B. "4K: SENDER" bei Live-TV)
      cleanName = cleanName.replaceAll(
        RegExp('^' + q + r'\s*:\s*', caseSensitive: false),
        '',
      );
      // Als eigenständiges Tag mit Leerzeichen/Trennzeichen drumherum (auch am Ende)
      cleanName = cleanName.replaceAll(
        RegExp(r'(?:^|\s)' + q + r'(?:\s*[\-\–\—\|:]\s*|\s+|$)', caseSensitive: false),
        ' ',
      );
      // Auch am Ende des Strings ohne Trennzeichen (z.B. "RELAX 11 3840P")
      cleanName = cleanName.replaceAll(
        RegExp(r'\s+' + q + r'$', caseSensitive: false),
        '',
      );
    }
    cleanName = cleanName.trim();

    // 2. Präfix-Tags am Anfang entfernen (iterativ, auch mehrere hintereinander)
    // Sortiere nach Länge (längste zuerst), damit "CA EN:" vor "CA:" matched
    final sortedPrefixes = List<String>.from(prefixTags)
      ..sort((a, b) => b.length.compareTo(a.length));

    bool foundPrefix = true;
    int iterations = 0;
    while (foundPrefix && iterations < 10) {
      foundPrefix = false;
      iterations++;

      for (final tag in sortedPrefixes) {
        // Pattern: Tag am Anfang, gefolgt von Trennzeichen (: - | etc.)
        final escapedTag = RegExp.escape(tag);
        final pattern = RegExp(
          '^' + escapedTag + r'\s*[\-\–\—\|:]+\s*',
          caseSensitive: false,
        );

        if (pattern.hasMatch(cleanName)) {
          cleanName = cleanName.replaceFirst(pattern, '');
          cleanName = cleanName.trim();
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
  final String? country; // Ländercode aus Präfix (DE, UK, US, etc.)
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
