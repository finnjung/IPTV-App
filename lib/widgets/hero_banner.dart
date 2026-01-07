import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/content_parser.dart';
import '../data/curated_content.dart';

/// Netflix-artiges Hero-Banner für die Startseite
class HeroBanner extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? quality;
  final String? language;
  final CuratedCategory? category;
  final VoidCallback? onPlay;

  const HeroBanner({
    super.key,
    required this.title,
    this.imageUrl,
    this.quality,
    this.language,
    this.category,
    this.onPlay,
  });

  /// Erstellt ein HeroBanner aus ContentMetadata und Basis-Infos
  factory HeroBanner.fromMetadata({
    Key? key,
    required String title,
    required ContentMetadata metadata,
    String? imageUrl,
    VoidCallback? onPlay,
  }) {
    return HeroBanner(
      key: key,
      title: metadata.cleanName,
      imageUrl: imageUrl,
      quality: metadata.quality,
      language: metadata.language,
      category: metadata.curatedMatch?.category,
      onPlay: onPlay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: 420,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : colorScheme.surface,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hintergrundbild
          if (imageUrl != null && imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildPlaceholder(context),
              errorWidget: (context, url, error) => _buildPlaceholder(context),
            )
          else
            _buildPlaceholder(context),

          // Gradient-Overlay von unten
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withAlpha(25),
                  Colors.black.withAlpha(100),
                  Colors.black.withAlpha(200),
                  isDark ? const Color(0xFF0F0F0F) : colorScheme.surface,
                ],
                stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              ),
            ),
          ),

          // Seitlicher Gradient (für Tiefe)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withAlpha(100),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withAlpha(50),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),

          // Content-Bereich
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Subtile Top-Zeile mit Kategorie-Icon und Text
                Row(
                  children: [
                    Icon(
                      _getCategoryIcon(category),
                      color: Colors.white.withAlpha(200),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getCategoryLabel(category),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(200),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Highlight des Tages',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary.withAlpha(230),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Titel
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: screenWidth > 600 ? 36 : 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        blurRadius: 20,
                        color: Colors.black.withAlpha(180),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                // Subtile Info-Zeile (Qualität + Sprache als Text)
                Row(
                  children: [
                    if (quality != null) ...[
                      _QualityChip(quality: quality!),
                      const SizedBox(width: 12),
                    ],
                    if (language != null)
                      Text(
                        ContentParser.languageCodes[language] ?? language!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withAlpha(180),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Play Button
                _PlayButton(onPressed: onPlay),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[900]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[800]! : Colors.grey[200]!,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withAlpha(30),
              colorScheme.surface,
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(CuratedCategory? category) {
    switch (category) {
      case CuratedCategory.movie:
        return Icons.movie_outlined;
      case CuratedCategory.series:
        return Icons.tv_outlined;
      case CuratedCategory.kids:
        return Icons.child_care_outlined;
      case CuratedCategory.documentary:
        return Icons.public_outlined;
      case null:
        return Icons.play_circle_outline;
    }
  }

  String _getCategoryLabel(CuratedCategory? category) {
    switch (category) {
      case CuratedCategory.movie:
        return 'Film';
      case CuratedCategory.series:
        return 'Serie';
      case CuratedCategory.kids:
        return 'Familienfilm';
      case CuratedCategory.documentary:
        return 'Dokumentation';
      case null:
        return 'Empfohlen';
    }
  }
}

/// Stilvoller Quality-Chip
class _QualityChip extends StatelessWidget {
  final String quality;

  const _QualityChip({required this.quality});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        quality,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (quality.toUpperCase()) {
      case '8K':
        return Colors.purpleAccent;
      case '4K':
      case 'UHD':
        return Colors.amber;
      case 'FHD':
      case '1080P':
        return Colors.lightBlueAccent;
      case 'HD':
      case '720P':
        return Colors.greenAccent;
      default:
        return Colors.white70;
    }
  }
}

/// Play-Button im Netflix-Stil
class _PlayButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _PlayButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 28,
              ),
              const SizedBox(width: 6),
              Text(
                'Abspielen',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leeres Hero-Banner (Placeholder wenn kein Spotlight verfügbar)
class HeroBannerPlaceholder extends StatelessWidget {
  const HeroBannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withAlpha(40),
            isDark ? const Color(0xFF0F0F0F) : colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 64,
              color: colorScheme.onSurface.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              'Lade Empfehlungen...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: colorScheme.onSurface.withAlpha(120),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
