import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

enum LegalPageType { privacy, impressum, terms }

class LegalPageScreen extends StatelessWidget {
  final LegalPageType type;

  const LegalPageScreen({super.key, required this.type});

  String get _title {
    switch (type) {
      case LegalPageType.privacy:
        return 'Datenschutz';
      case LegalPageType.impressum:
        return 'Impressum';
      case LegalPageType.terms:
        return 'Nutzungsbedingungen';
    }
  }

  String get _icon {
    switch (type) {
      case LegalPageType.privacy:
        return 'assets/icons/shield-check.svg';
      case LegalPageType.impressum:
        return 'assets/icons/file-text.svg';
      case LegalPageType.terms:
        return 'assets/icons/scales.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final extraTopPadding = !kIsWeb && Platform.isMacOS ? 28.0 : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header mit Zurück-Button
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8 + extraTopPadding, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: SvgPicture.asset(
                      'assets/icons/arrow-left.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    _icon,
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: _buildContent(colorScheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    switch (type) {
      case LegalPageType.privacy:
        return _PrivacyContent(colorScheme: colorScheme);
      case LegalPageType.impressum:
        return _ImpressumContent(colorScheme: colorScheme);
      case LegalPageType.terms:
        return _TermsContent(colorScheme: colorScheme);
    }
  }
}

// === DATENSCHUTZ ===
class _PrivacyContent extends StatelessWidget {
  final ColorScheme colorScheme;

  const _PrivacyContent({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          'Einleitung',
          'Mit dieser Datenschutzerklarung informieren wir Sie uber die Verarbeitung '
              'personenbezogener Daten bei der Nutzung dieser App.',
        ),
        _buildSection(
          'Verantwortlicher',
          'Verantwortlich fur die Datenverarbeitung ist der Betreiber dieser App. '
              'Kontaktdaten finden Sie im Impressum.',
        ),
        _buildSection(
          'Welche Daten werden verarbeitet?',
          'Diese App verarbeitet ausschliesslich die Daten, die Sie selbst eingeben:\n\n'
              '• Server-URL Ihres IPTV-Anbieters\n'
              '• Benutzername und Passwort fur Ihren IPTV-Zugang\n'
              '• Ihre Sprachpraferenz\n'
              '• Liste der ausgeblendeten Serien\n\n'
              'Diese Daten werden ausschliesslich lokal auf Ihrem Gerat gespeichert '
              'und nicht an uns oder Dritte ubermittelt.',
        ),
        _buildSection(
          'Datenspeicherung',
          'Alle Daten werden lokal auf Ihrem Gerat im sicheren App-Speicher abgelegt. '
              'Eine Ubertragung an externe Server findet nicht statt, '
              'ausser zu dem von Ihnen angegebenen IPTV-Server.',
        ),
        _buildSection(
          'Kommunikation mit IPTV-Servern',
          'Diese App kommuniziert direkt mit dem IPTV-Server, den Sie konfigurieren. '
              'Die Verantwortung fur den Datenschutz auf Seiten des IPTV-Servers liegt '
              'bei dem jeweiligen Anbieter. Wir haben keinen Einfluss auf die '
              'Datenverarbeitung durch Drittanbieter.',
        ),
        _buildSection(
          'Keine Analyse oder Tracking',
          'Diese App verwendet keine Analyse-Tools, Tracking-Dienste oder Werbung. '
              'Es werden keine Nutzungsdaten erhoben oder an Dritte weitergegeben.',
        ),
        _buildSection(
          'Ihre Rechte',
          'Sie haben das Recht auf Auskunft, Berichtigung, Loschung und '
              'Einschrankung der Verarbeitung Ihrer Daten. Da alle Daten lokal '
              'gespeichert werden, konnen Sie diese jederzeit durch Loschen der App '
              'oder Trennen der Verbindung in den Einstellungen entfernen.',
        ),
        _buildSection(
          'Anderungen',
          'Wir behalten uns vor, diese Datenschutzerklarung anzupassen, '
              'um sie an geanderte Rechtslagen oder Anderungen der App anzupassen.',
        ),
        const SizedBox(height: 20),
        _buildLastUpdated('Stand: Januar 2025'),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurface.withAlpha(200),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: colorScheme.onSurface.withAlpha(120),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// === IMPRESSUM ===
class _ImpressumContent extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ImpressumContent({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          'Angaben gemass § 5 TMG',
          'Finn Jung\n'
              'Einzelunternehmer\n'
              'Rotlintstrasse 79\n'
              '60389 Frankfurt am Main\n'
              'Deutschland',
        ),
        _buildSection(
          'Kontakt',
          'E-Mail: info@immo-fluss.de\n'
              'Telefon: 0160 7703496',
        ),
        _buildSection(
          'Verantwortlich fur den Inhalt nach § 55 Abs. 2 RStV',
          'Finn Jung\n'
              'Rotlintstrasse 79\n'
              '60389 Frankfurt am Main',
        ),
        _buildSection(
          'Haftungsausschluss',
          'Haftung fur Inhalte\n\n'
              'Diese App dient lediglich als technische Schnittstelle zur Wiedergabe '
              'von IPTV-Streams. Die Inhalte werden von externen IPTV-Servern bereitgestellt, '
              'auf die wir keinen Einfluss haben.\n\n'
              'Wir ubernehmen keine Haftung fur die Rechtmassigkeit, Richtigkeit, '
              'Vollstandigkeit oder Qualitat der uber diese App abgerufenen Inhalte. '
              'Die Verantwortung fur die Inhalte liegt ausschliesslich bei den '
              'jeweiligen IPTV-Anbietern.',
        ),
        _buildSection(
          'Haftung fur Links',
          'Diese App kann Verbindungen zu externen Servern herstellen. '
              'Fur den Inhalt der externen Server sind ausschliesslich deren Betreiber verantwortlich. '
              'Zum Zeitpunkt der Verbindungsherstellung waren keine rechtswidrigen Inhalte erkennbar.',
        ),
        _buildSection(
          'Urheberrecht',
          'Die durch uns erstellten Inhalte und Werke in dieser App unterliegen dem deutschen Urheberrecht. '
              'Die Vervielfaltigung, Bearbeitung, Verbreitung und jede Art der Verwertung ausserhalb der Grenzen '
              'des Urheberrechts bedurfen der schriftlichen Zustimmung des Erstellers.',
        ),
        const SizedBox(height: 20),
        _buildLastUpdated('Stand: Januar 2025'),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurface.withAlpha(200),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: colorScheme.onSurface.withAlpha(120),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// === NUTZUNGSBEDINGUNGEN ===
class _TermsContent extends StatelessWidget {
  final ColorScheme colorScheme;

  const _TermsContent({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wichtiger Hinweis zur legalen Nutzung
        _buildWarningBox(
          'Wichtiger Hinweis zur Nutzung',
          'Diese App ist ausschliesslich fur die Nutzung mit legalen IPTV-Diensten bestimmt. '
              'Die Nutzung illegaler Streams oder urheberrechtlich geschutzter Inhalte ohne entsprechende '
              'Berechtigung ist strengstens untersagt und kann strafrechtliche Konsequenzen haben.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          '1. Geltungsbereich',
          'Diese Nutzungsbedingungen regeln die Nutzung dieser IPTV-Player-App. '
              'Mit der Installation und Nutzung der App akzeptieren Sie diese Bedingungen vollstandig.',
        ),
        _buildSection(
          '2. Beschreibung der App',
          'Diese App ist ein reiner IPTV-Player, der es ermoglicht, Inhalte von externen '
              'IPTV-Servern abzuspielen. Die App selbst stellt keine Inhalte bereit und hostet '
              'keine Streams. Sie dient lediglich als technische Schnittstelle zwischen dem '
              'Nutzer und dem vom Nutzer gewahlten IPTV-Anbieter.',
        ),
        _buildSection(
          '3. Legale Nutzung - WICHTIG',
          'Der Nutzer verpflichtet sich ausdrucklich:\n\n'
              '• Die App ausschliesslich mit legalen und lizenzierten IPTV-Diensten zu verwenden\n\n'
              '• Keine urheberrechtlich geschutzten Inhalte ohne entsprechende Berechtigung abzurufen\n\n'
              '• Keine illegalen IPTV-Server oder Streaming-Quellen zu nutzen\n\n'
              '• Sich vor der Nutzung eines IPTV-Dienstes uber dessen Legalitat zu informieren\n\n'
              '• Alle geltenden Gesetze und Vorschriften zum Urheberrecht einzuhalten',
        ),
        _buildSection(
          '4. Haftungsausschluss',
          'Wir distanzieren uns ausdrucklich von jeglicher illegaler Nutzung dieser App:\n\n'
              '• Wir ubernehmen keine Verantwortung fur Inhalte, die uber externe IPTV-Server '
              'bereitgestellt werden\n\n'
              '• Wir haben keine Kontrolle uber die Streams, die Nutzer uber ihre eigenen '
              'IPTV-Zugangsdaten abrufen\n\n'
              '• Die Verantwortung fur die Legalitat der genutzten IPTV-Dienste liegt '
              'ausschliesslich beim Nutzer\n\n'
              '• Wir unterstutzen, fordern oder tolerieren keine Form von Urheberrechtsverletzungen',
        ),
        _buildSection(
          '5. Keine Gewahrleistung',
          'Die App wird "wie besehen" ohne jegliche Garantie bereitgestellt. Wir ubernehmen '
              'keine Gewahrleistung fur:\n\n'
              '• Die Verfugbarkeit oder Qualitat externer IPTV-Streams\n'
              '• Die Kompatibilitat mit allen IPTV-Anbietern\n'
              '• Die ununterbrochene oder fehlerfreie Funktion der App\n'
              '• Datenverluste oder andere Schaden durch die Nutzung der App',
        ),
        _buildSection(
          '6. Verantwortung des Nutzers',
          'Der Nutzer ist allein verantwortlich fur:\n\n'
              '• Die Auswahl und Nutzung eines legalen IPTV-Anbieters\n'
              '• Die Sicherheit seiner Zugangsdaten\n'
              '• Die Einhaltung der Nutzungsbedingungen seines IPTV-Anbieters\n'
              '• Alle rechtlichen Konsequenzen aus der Nutzung illegaler Inhalte',
        ),
        _buildSection(
          '7. Beendigung der Nutzung',
          'Wir behalten uns das Recht vor, die Bereitstellung der App jederzeit einzustellen. '
              'Der Nutzer kann die Nutzung jederzeit durch Deinstallation der App beenden.',
        ),
        _buildSection(
          '8. Salvatorische Klausel',
          'Sollten einzelne Bestimmungen dieser Nutzungsbedingungen unwirksam sein oder werden, '
              'bleibt die Wirksamkeit der ubrigen Bestimmungen davon unberuhrt.',
        ),
        _buildSection(
          '9. Anderungen der Nutzungsbedingungen',
          'Wir behalten uns vor, diese Nutzungsbedingungen jederzeit zu andern. '
              'Die fortgesetzte Nutzung der App nach Anderungen gilt als Zustimmung zu den '
              'geanderten Bedingungen.',
        ),
        _buildSection(
          '10. Anwendbares Recht',
          'Es gilt das Recht der Bundesrepublik Deutschland unter Ausschluss des '
              'UN-Kaufrechts.',
        ),
        const SizedBox(height: 20),
        _buildLastUpdated('Stand: Januar 2025'),
      ],
    );
  }

  Widget _buildWarningBox(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurface.withAlpha(220),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurface.withAlpha(200),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: colorScheme.onSurface.withAlpha(120),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
