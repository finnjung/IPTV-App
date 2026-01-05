import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/xtream_service.dart';
import '../utils/content_parser.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Widget _buildEmptySeriesSection(ColorScheme colorScheme, XtreamService xtreamService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Leere Serien',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withAlpha(150),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withAlpha(25),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Info-Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withAlpha(10),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/info.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withAlpha(150),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Manche Serien haben keine Episoden hinterlegt. '
                        'Für eine bessere Nutzererfahrung werden diese automatisch ausgeblendet, '
                        'sobald du sie einmal öffnest.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: colorScheme.onSurface.withAlpha(180),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/eye-slash.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          colorScheme.onSurface.withAlpha(180),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Automatisch ausblenden',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            xtreamService.autoHideEmptySeries
                                ? 'Leere Serien werden versteckt'
                                : 'Alle Serien werden angezeigt',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: xtreamService.autoHideEmptySeries,
                      onChanged: (value) {
                        xtreamService.setAutoHideEmptySeries(value);
                      },
                      activeTrackColor: colorScheme.onSurface.withAlpha(100),
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return colorScheme.onSurface;
                        }
                        return null;
                      }),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                indent: 60,
                color: colorScheme.outline.withAlpha(25),
              ),

              // Ausgeblendete Serien Zähler & Reset
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: xtreamService.emptySeriesCount > 0 ? _showResetBottomSheet : null,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/arrows-clockwise.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface.withAlpha(180),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ausgeblendete Serien',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                xtreamService.emptySeriesCount > 0
                                    ? '${xtreamService.emptySeriesCount} Serien ausgeblendet'
                                    : 'Keine Serien ausgeblendet',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withAlpha(150),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (xtreamService.emptySeriesCount > 0)
                          SvgPicture.asset(
                            'assets/icons/caret-right.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface.withAlpha(100),
                              BlendMode.srcIn,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSection(ColorScheme colorScheme, XtreamService xtreamService) {
    final currentLanguage = xtreamService.preferredLanguage;
    final languageName = currentLanguage != null
        ? ContentParser.languageCodes[currentLanguage] ?? currentLanguage
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Sprache',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withAlpha(150),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withAlpha(25),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Info-Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withAlpha(10),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/info.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withAlpha(150),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Inhalte in deiner bevorzugten Sprache werden auf der Startseite priorisiert angezeigt.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: colorScheme.onSurface.withAlpha(180),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Language Selection
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showLanguageBottomSheet,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/globe.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface.withAlpha(180),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bevorzugte Sprache',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                languageName ?? 'Keine Präferenz',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withAlpha(150),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/icons/caret-right.svg',
                          width: 18,
                          height: 18,
                          colorFilter: ColorFilter.mode(
                            colorScheme.onSurface.withAlpha(100),
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLanguageBottomSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.read<XtreamService>();

    // Die häufigsten Sprachen zuerst
    final priorityLanguages = ['DE', 'EN', 'TR', 'FR', 'ES', 'IT', 'AR', 'RU', 'PL'];
    final otherLanguages = ContentParser.languageCodes.keys
        .where((code) => !priorityLanguages.contains(code) && code.length <= 2)
        .toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Bevorzugte Sprache',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Language List
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // "Keine Präferenz" Option
                  _LanguageOption(
                    code: null,
                    name: 'Keine Präferenz',
                    isSelected: xtreamService.preferredLanguage == null,
                    onTap: () {
                      xtreamService.setPreferredLanguage(null);
                      Navigator.pop(context);
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      height: 1,
                      color: colorScheme.outline.withAlpha(25),
                    ),
                  ),

                  // Priority Languages
                  ...priorityLanguages.map((code) => _LanguageOption(
                        code: code,
                        name: ContentParser.languageCodes[code] ?? code,
                        isSelected: xtreamService.preferredLanguage == code,
                        onTap: () {
                          xtreamService.setPreferredLanguage(code);
                          Navigator.pop(context);
                        },
                      )),

                  if (otherLanguages.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        height: 1,
                        color: colorScheme.outline.withAlpha(25),
                      ),
                    ),

                    // Other Languages
                    ...otherLanguages.map((code) => _LanguageOption(
                          code: code,
                          name: ContentParser.languageCodes[code] ?? code,
                          isSelected: xtreamService.preferredLanguage == code,
                          onTap: () {
                            xtreamService.setPreferredLanguage(code);
                            Navigator.pop(context);
                          },
                        )),
                  ],
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showResetBottomSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.read<XtreamService>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/arrows-clockwise.svg',
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface.withAlpha(180),
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Ausgeblendete Serien zurücksetzen?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              'Alle ${xtreamService.emptySeriesCount} als leer markierten Serien werden wieder angezeigt. '
              'Leere Serien werden beim nächsten Öffnen erneut ausgeblendet.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurface.withAlpha(150),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: colorScheme.outline.withAlpha(50)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Abbrechen',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      xtreamService.clearEmptySeriesIds();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Zurücksetzen',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugSection(ColorScheme colorScheme, XtreamService xtreamService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Debug / Entwicklung',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.error.withAlpha(200),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.error.withAlpha(50),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showDebugAnalysis(xtreamService),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/broadcast.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          colorScheme.error.withAlpha(200),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live TV Kürzel analysieren',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Präfixe/Suffixe und Sonderzeichen finden',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SvgPicture.asset(
                      'assets/icons/caret-right.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withAlpha(100),
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDebugAnalysis(XtreamService xtreamService) async {
    final colorScheme = Theme.of(context).colorScheme;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Analysiere Live-Sender...',
                style: GoogleFonts.poppins(color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );

    // Load streams
    final streams = await xtreamService.getLiveStreams();

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    // Analyse prefixes/suffixes with colon
    final prefixesWithColon = <String, int>{};
    final suffixesWithColon = <String, int>{};
    final titlesWithSpecialChars = <String>[];
    final allTitles = <String>[];

    // Regex für Sonderzeichen (nicht ASCII-Buchstaben/Zahlen/normale Zeichen)
    final specialCharPattern = RegExp(r'[^\x00-\x7F]');
    // Regex für typische "Qualitäts"-Sonderzeichen (Unicode-Varianten)
    final qualitySpecialPattern = RegExp(r'[①②③④⑤⑥⑦⑧⑨⓪ⓊⒽⒹ🅄🅗🅓⁴ᵏ⁴ᴷ⁴ᴷ⁺ᵁᴴᴰᶠᴴᴰ⟮⟯「」『』【】〖〗〔〕｜]');

    for (final stream in streams) {
      final name = stream.name ?? '';
      allTitles.add(name);

      // Check for special characters
      if (specialCharPattern.hasMatch(name) || qualitySpecialPattern.hasMatch(name)) {
        titlesWithSpecialChars.add(name);
      }

      // Extract prefix before colon (e.g., "4K:" -> "4K")
      final prefixMatch = RegExp(r'^([^:]{1,20}):').firstMatch(name);
      if (prefixMatch != null) {
        final prefix = prefixMatch.group(1)!.trim().toUpperCase();
        prefixesWithColon[prefix] = (prefixesWithColon[prefix] ?? 0) + 1;
      }

      // Extract suffix after colon at end (e.g., ":HD" -> "HD")
      final suffixMatch = RegExp(r':([^:]{1,20})$').firstMatch(name);
      if (suffixMatch != null) {
        final suffix = suffixMatch.group(1)!.trim().toUpperCase();
        suffixesWithColon[suffix] = (suffixesWithColon[suffix] ?? 0) + 1;
      }
    }

    // Sort by frequency
    final sortedPrefixes = prefixesWithColon.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedSuffixes = suffixesWithColon.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Build report
    final report = StringBuffer();
    report.writeln('=== LIVE TV ANALYSE ===');
    report.writeln('Gesamt: ${streams.length} Sender\n');

    report.writeln('--- PRÄFIXE MIT DOPPELPUNKT (${sortedPrefixes.length} unique) ---');
    for (final entry in sortedPrefixes) {
      report.writeln('  ${entry.key}: (${entry.value}x)');
    }

    report.writeln('\n--- SUFFIXE MIT DOPPELPUNKT (${sortedSuffixes.length} unique) ---');
    for (final entry in sortedSuffixes) {
      report.writeln('  :${entry.key} (${entry.value}x)');
    }

    report.writeln('\n--- TITEL MIT SONDERZEICHEN (${titlesWithSpecialChars.length}) ---');
    for (final title in titlesWithSpecialChars.take(100)) {
      report.writeln('  $title');
    }
    if (titlesWithSpecialChars.length > 100) {
      report.writeln('  ... und ${titlesWithSpecialChars.length - 100} weitere');
    }

    final reportText = report.toString();

    // Also print to console
    debugPrint(reportText);

    // Show bottom sheet with results
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title + Copy Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Live TV Analyse',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: reportText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('In Zwischenablage kopiert!', style: GoogleFonts.poppins()),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text('Kopieren', style: GoogleFonts.poppins(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _StatChip(label: '${streams.length} Sender', colorScheme: colorScheme),
                    const SizedBox(width: 8),
                    _StatChip(label: '${sortedPrefixes.length} Präfixe', colorScheme: colorScheme),
                    const SizedBox(width: 8),
                    _StatChip(label: '${titlesWithSpecialChars.length} Sonderz.', colorScheme: colorScheme),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SelectableText(
                    reportText,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: colorScheme.onSurface.withAlpha(220),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();

    // Show login screen if not connected
    if (!xtreamService.isConnected) {
      return LoginScreen(
        onLoginSuccess: () {
          // Navigation will update automatically via Provider
        },
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/user.svg',
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Profil',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Connection Status Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.onSurface.withAlpha(40),
                        colorScheme.onSurface.withAlpha(25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/plug.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verbunden',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            if (xtreamService.credentials != null)
                              Text(
                                xtreamService.credentials!.serverUrl,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withAlpha(200),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.greenAccent,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                // Server Info
                if (xtreamService.serverInfo != null) ...[
                  const SizedBox(height: 24),
                  _buildSection(
                    context,
                    'Server Info',
                    [
                      _SettingsItem(
                        icon: 'assets/icons/user.svg',
                        title: 'Benutzername',
                        subtitle:
                            xtreamService.serverInfo!.userInfo.username ?? '-',
                      ),
                      _SettingsItem(
                        icon: 'assets/icons/clock.svg',
                        title: 'Account gültig bis',
                        subtitle: _formatExpDate(
                            xtreamService.serverInfo!.userInfo.expDate),
                      ),
                      _SettingsItem(
                        icon: 'assets/icons/link.svg',
                        title: 'Aktive Verbindungen',
                        subtitle:
                            '${xtreamService.serverInfo!.userInfo.activeCons ?? 0} / ${xtreamService.serverInfo!.userInfo.maxConnections ?? 1}',
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Content Stats
                _buildSection(
                  context,
                  'Verfügbare Inhalte',
                  [
                    _SettingsItem(
                      icon: 'assets/icons/broadcast.svg',
                      title: 'Live TV Kategorien',
                      subtitle:
                          '${xtreamService.liveCategories?.length ?? 0} Kategorien',
                    ),
                    _SettingsItem(
                      icon: 'assets/icons/film-strip.svg',
                      title: 'Film Kategorien',
                      subtitle:
                          '${xtreamService.vodCategories?.length ?? 0} Kategorien',
                    ),
                    _SettingsItem(
                      icon: 'assets/icons/monitor-play.svg',
                      title: 'Serien Kategorien',
                      subtitle:
                          '${xtreamService.seriesCategories?.length ?? 0} Kategorien',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Leere Serien ausblenden
                _buildEmptySeriesSection(colorScheme, xtreamService),

                const SizedBox(height: 24),

                // Spracheinstellungen
                _buildLanguageSection(colorScheme, xtreamService),

                const SizedBox(height: 24),

                // App Settings
                _buildSection(
                  context,
                  'App',
                  [
                    _SettingsItem(
                      icon: 'assets/icons/moon.svg',
                      title: 'Erscheinungsbild',
                      subtitle: 'Dunkel',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: 'assets/icons/info.svg',
                      title: 'Über',
                      subtitle: 'Version 1.0.0',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Debug: Live TV Analyse
                _buildDebugSection(colorScheme, xtreamService),

                const SizedBox(height: 24),

                // Disconnect Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDisconnect(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error.withAlpha(100)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: SvgPicture.asset(
                      'assets/icons/sign-out.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colorScheme.error,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: Text(
                      'Verbindung trennen',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatExpDate(DateTime? expDate) {
    if (expDate == null) return '-';
    return '${expDate.day}.${expDate.month}.${expDate.year}';
  }

  void _confirmDisconnect(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Verbindung trennen?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Deine Zugangsdaten werden gelöscht und du musst dich erneut anmelden.',
          style: GoogleFonts.poppins(
            color: colorScheme.onSurface.withAlpha(180),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Abbrechen',
              style: GoogleFonts.poppins(
                color: colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<XtreamService>().disconnect();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: Text(
              'Trennen',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<_SettingsItem> items,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withAlpha(150),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withAlpha(25),
              width: 1,
            ),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: item.onTap,
                      borderRadius: BorderRadius.vertical(
                        top: index == 0
                            ? const Radius.circular(16)
                            : Radius.zero,
                        bottom: index == items.length - 1
                            ? const Radius.circular(16)
                            : Radius.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface.withAlpha(15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SvgPicture.asset(
                                item.icon,
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  colorScheme.onSurface.withAlpha(180),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color:
                                          colorScheme.onSurface.withAlpha(150),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.onTap != null)
                              SvgPicture.asset(
                                'assets/icons/caret-right.svg',
                                width: 18,
                                height: 18,
                                colorFilter: ColorFilter.mode(
                                  colorScheme.onSurface.withAlpha(100),
                                  BlendMode.srcIn,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (index < items.length - 1)
                    Divider(
                      height: 1,
                      indent: 60,
                      color: colorScheme.outline.withAlpha(25),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
}

class _StatChip extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const _StatChip({required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface.withAlpha(180),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String? code;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.code,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.onSurface.withAlpha(15) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Language code badge
              if (code != null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.onSurface.withAlpha(30)
                        : colorScheme.onSurface.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      code!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withAlpha(isSelected ? 255 : 180),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.onSurface.withAlpha(30)
                        : colorScheme.onSurface.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/globe.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withAlpha(isSelected ? 255 : 150),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),

              const SizedBox(width: 14),

              // Language name
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: colorScheme.onSurface.withAlpha(isSelected ? 255 : 200),
                  ),
                ),
              ),

              // Checkmark
              if (isSelected)
                SvgPicture.asset(
                  'assets/icons/check.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

