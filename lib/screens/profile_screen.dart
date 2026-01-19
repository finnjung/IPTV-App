import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/xtream_service.dart';
import '../services/app_update_service.dart';
import '../utils/content_parser.dart';
import '../widgets/update_dialog.dart';
import 'login_screen.dart';
import 'legal_page_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isCheckingUpdate = false;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    if (!kIsWeb && Platform.isAndroid) {
      final version = await context.read<AppUpdateService>().getVersionName();
      if (mounted) {
        setState(() => _appVersion = version);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
        // Info-Box (nicht interaktiv)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withAlpha(10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withAlpha(25),
              width: 1,
            ),
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
        const SizedBox(height: 12),
        // Toggle - fokussierbar
        _FocusableProfileItem(
          onTap: () {
            xtreamService.setAutoHideEmptySeries(!xtreamService.autoHideEmptySeries);
          },
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withAlpha(25),
                width: 1,
              ),
            ),
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
                    activeTrackColor: Colors.green,
                    activeThumbColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Ausgeblendete Serien Zähler & Reset - fokussierbar
        _FocusableProfileItem(
          onTap: xtreamService.emptySeriesCount > 0 ? _showResetBottomSheet : null,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withAlpha(25),
                width: 1,
              ),
            ),
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
        // Info-Box (nicht interaktiv)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withAlpha(10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withAlpha(25),
              width: 1,
            ),
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
        const SizedBox(height: 12),
        // Language Selection - fokussierbar
        _FocusableProfileItem(
          onTap: _showLanguageBottomSheet,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withAlpha(25),
                width: 1,
              ),
            ),
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
      constraints: const BoxConstraints(maxWidth: 500),
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
      constraints: const BoxConstraints(maxWidth: 500),
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

  bool _isRefreshing = false;

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return;

    setState(() => _isCheckingUpdate = true);

    try {
      final updateService = context.read<AppUpdateService>();
      final updateInfo = await updateService.checkForUpdate();

      if (mounted) {
        if (updateInfo != null) {
          await UpdateDialog.show(context, updateInfo);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Du hast bereits die neueste Version',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fehler beim Prüfen auf Updates',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _refreshAllContent() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await context.read<XtreamService>().refreshAllContent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inhalte wurden aktualisiert',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fehler beim Aktualisieren: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Widget _buildAppSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'App',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withAlpha(150),
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Inhalte neu laden
        _FocusableProfileItem(
          onTap: _isRefreshing ? null : _refreshAllContent,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withAlpha(25),
                width: 1,
              ),
            ),
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
                    child: _isRefreshing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onSurface.withAlpha(180),
                            ),
                          )
                        : SvgPicture.asset(
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
                          'Inhalte neu laden',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isRefreshing
                              ? 'Wird aktualisiert...'
                              : 'Filme, Serien & Live TV aktualisieren',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isRefreshing)
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
        const SizedBox(height: 12),
        // Erscheinungsbild
        _FocusableProfileItem(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withAlpha(25),
                width: 1,
              ),
            ),
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
                      'assets/icons/moon.svg',
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
                          'Erscheinungsbild',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dunkel',
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
        // Nach Updates suchen (nur auf Android/Fire TV)
        if (!kIsWeb && Platform.isAndroid) ...[
          const SizedBox(height: 12),
          _FocusableProfileItem(
            onTap: _isCheckingUpdate ? null : _checkForUpdates,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withAlpha(25),
                  width: 1,
                ),
              ),
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
                      child: _isCheckingUpdate
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onSurface.withAlpha(180),
                              ),
                            )
                          : SvgPicture.asset(
                              'assets/icons/arrow-circle-up.svg',
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
                            'Nach Updates suchen',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isCheckingUpdate
                                ? 'Wird geprüft...'
                                : 'Aktuelle Version: $_appVersion',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isCheckingUpdate)
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
      ],
    );
  }

  Widget _buildLegalSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Rechtliches',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withAlpha(150),
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Datenschutz
        _FocusableProfileItem(
          onTap: () => _navigateToLegalPage(LegalPageType.privacy),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(
                color: colorScheme.outline.withAlpha(25),
                width: 1,
              ),
            ),
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
                      'assets/icons/shield-check.svg',
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
                          'Datenschutz',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Datenschutzerklarung',
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
        // Impressum
        _FocusableProfileItem(
          onTap: () => _navigateToLegalPage(LegalPageType.impressum),
          borderRadius: BorderRadius.zero,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                left: BorderSide(color: colorScheme.outline.withAlpha(25), width: 1),
                right: BorderSide(color: colorScheme.outline.withAlpha(25), width: 1),
              ),
            ),
            child: Column(
              children: [
                Divider(
                  height: 1,
                  indent: 60,
                  color: colorScheme.outline.withAlpha(25),
                ),
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
                          'assets/icons/file-text.svg',
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
                              'Impressum',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Anbieterkennzeichnung',
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
              ],
            ),
          ),
        ),
        // Nutzungsbedingungen
        _FocusableProfileItem(
          onTap: () => _navigateToLegalPage(LegalPageType.terms),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border.all(
                color: colorScheme.outline.withAlpha(25),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Divider(
                  height: 1,
                  indent: 60,
                  color: colorScheme.outline.withAlpha(25),
                ),
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
                          'assets/icons/scales.svg',
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
                              'Nutzungsbedingungen',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'AGB & Haftungsausschluss',
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToLegalPage(LegalPageType type) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LegalPageScreen(type: type),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final screenWidth = MediaQuery.of(context).size.width;

    // Show login screen if not connected
    if (!xtreamService.isConnected) {
      return LoginScreen(
        onLoginSuccess: () {
          // Navigation will update automatically via Provider
        },
      );
    }

    // Extra Padding für macOS wegen Traffic Lights
    final extraTopPadding = !kIsWeb && Platform.isMacOS ? 28.0 : 0.0;

    // Responsive Breakpoints
    final bool isDesktop = screenWidth > 900;
    final double horizontalPadding = isDesktop ? 40.0 : 20.0;
    const double maxContentWidth = 1200.0;
    const double columnSpacing = 24.0;

    // Connection Status Card Widget (wiederverwendbar)
    Widget connectionStatusCard = Container(
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
    );

    // Disconnect Button Widget
    Widget disconnectButton = _FocusableProfileItem(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _confirmDisconnect(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.error.withAlpha(100)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/sign-out.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                colorScheme.error,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Verbindung trennen',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );

    // Linke Spalte: Account & Server Info
    Widget leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection Status
        connectionStatusCard,

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
                subtitle: xtreamService.serverInfo!.userInfo.username ?? '-',
              ),
              _SettingsItem(
                icon: 'assets/icons/clock.svg',
                title: 'Account gültig bis',
                subtitle: _formatExpDate(xtreamService.serverInfo!.userInfo.expDate),
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
              subtitle: '${xtreamService.liveCategories?.length ?? 0} Kategorien',
            ),
            _SettingsItem(
              icon: 'assets/icons/film-strip.svg',
              title: 'Film Kategorien',
              subtitle: '${xtreamService.vodCategories?.length ?? 0} Kategorien',
            ),
            _SettingsItem(
              icon: 'assets/icons/monitor-play.svg',
              title: 'Serien Kategorien',
              subtitle: '${xtreamService.seriesCategories?.length ?? 0} Kategorien',
            ),
          ],
        ),

      ],
    );

    // Rechte Spalte: Einstellungen
    Widget rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leere Serien
        _buildEmptySeriesSection(colorScheme, xtreamService),

        const SizedBox(height: 24),

        // Spracheinstellungen
        _buildLanguageSection(colorScheme, xtreamService),

        const SizedBox(height: 24),

        // App Settings
        _buildAppSection(colorScheme),

        const SizedBox(height: 24),

        // Rechtliches
        _buildLegalSection(colorScheme),

        // Disconnect Button in rechter Spalte auf Desktop
        if (isDesktop) ...[
          const SizedBox(height: 24),
          disconnectButton,
        ],
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20 + extraTopPadding,
                horizontalPadding,
                20,
              ),
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

                  // Desktop: Zweispalten-Layout
                  if (isDesktop)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Linke Spalte
                          Expanded(child: leftColumn),
                          const SizedBox(width: columnSpacing),
                          // Rechte Spalte
                          Expanded(child: rightColumn),
                        ],
                      ),
                    )
                  // Mobile: Einspalten-Layout
                  else ...[
                    connectionStatusCard,

                    if (xtreamService.serverInfo != null) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        'Server Info',
                        [
                          _SettingsItem(
                            icon: 'assets/icons/user.svg',
                            title: 'Benutzername',
                            subtitle: xtreamService.serverInfo!.userInfo.username ?? '-',
                          ),
                          _SettingsItem(
                            icon: 'assets/icons/clock.svg',
                            title: 'Account gültig bis',
                            subtitle: _formatExpDate(xtreamService.serverInfo!.userInfo.expDate),
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
                    _buildSection(
                      context,
                      'Verfügbare Inhalte',
                      [
                        _SettingsItem(
                          icon: 'assets/icons/broadcast.svg',
                          title: 'Live TV Kategorien',
                          subtitle: '${xtreamService.liveCategories?.length ?? 0} Kategorien',
                        ),
                        _SettingsItem(
                          icon: 'assets/icons/film-strip.svg',
                          title: 'Film Kategorien',
                          subtitle: '${xtreamService.vodCategories?.length ?? 0} Kategorien',
                        ),
                        _SettingsItem(
                          icon: 'assets/icons/monitor-play.svg',
                          title: 'Serien Kategorien',
                          subtitle: '${xtreamService.seriesCategories?.length ?? 0} Kategorien',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _buildEmptySeriesSection(colorScheme, xtreamService),

                    const SizedBox(height: 24),
                    _buildLanguageSection(colorScheme, xtreamService),

                    const SizedBox(height: 24),
                    _buildAppSection(colorScheme),

                    const SizedBox(height: 24),
                    _buildLegalSection(colorScheme),

                    const SizedBox(height: 24),
                    disconnectButton,
                  ],

                  const SizedBox(height: 100),
                ],
              ),
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

/// Fokussierbarer Container für Profil-Elemente mit weißem Rahmen und Smooth Scrolling
class _FocusableProfileItem extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool autofocus;

  const _FocusableProfileItem({
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.autofocus = false,
  });

  @override
  State<_FocusableProfileItem> createState() => _FocusableProfileItemState();
}

class _FocusableProfileItemState extends State<_FocusableProfileItem>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() {
      _isFocused = hasFocus;
    });
    if (hasFocus) {
      _scaleController.forward();
      // Smooth scroll zum fokussierten Element
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.3,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } else {
      _scaleController.reverse();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: true,
      skipTraversal: false,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: _isFocused ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: Colors.white.withAlpha(40),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

