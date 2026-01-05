import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/xtream_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                        colorScheme.primary,
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
                        colorScheme.primary,
                        colorScheme.primary.withAlpha(180),
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
              color: colorScheme.primary,
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
                                color: colorScheme.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SvgPicture.asset(
                                item.icon,
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  colorScheme.primary,
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
