import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../widgets/content_card.dart';
import '../widgets/sticky_glass_header.dart';
import '../widgets/section_header.dart';
import '../widgets/responsive_grid.dart';
import '../utils/content_parser.dart';
import 'series_detail_screen.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  bool _showAllSeries = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final xtreamService = context.read<XtreamService>();
    if (xtreamService.isConnected) {
      await xtreamService.loadSeriesScreenContent();
    }
  }

  void _openSeries(XTremeCodeSeriesItem series) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeriesDetailScreen(series: series),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final content = xtreamService.seriesScreenContent;
    final isLoading = xtreamService.isLoadingSeries;

    return Scaffold(
      body: !xtreamService.isConnected
          ? SafeArea(child: _buildNotConnected(context))
          : CustomScrollView(
              slivers: [
                // Sticky Glass Header
                StickyGlassHeader(
                  title: 'Serien',
                  subtitle: isLoading
                      ? 'Laden...'
                      : '${content?.allSeriesSorted.length ?? 0} Serien verfugbar',
                  iconPath: 'assets/icons/monitor-play.svg',
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Loading
                if (isLoading || content == null)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                else if (content.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState(colorScheme))
                else ...[
                  // Pseudo-Category Sections
                  for (final category in content.categories) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: SectionHeader(
                          title: category.title,
                          icon: category.icon,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: category.items.length,
                          itemBuilder: (context, index) {
                            final series = category.items[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < category.items.length - 1 ? 12 : 0,
                              ),
                              child: _SeriesCard(
                                series: series,
                                onTap: () => _openSeries(series),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // All Series Section Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                      child: SectionHeader(
                        title: 'Alle Serien (A-Z)',
                        icon: 'assets/icons/list.svg',
                        onSeeAll: _showAllSeries
                            ? null
                            : () => setState(() => _showAllSeries = true),
                      ),
                    ),
                  ),

                  // All Series Grid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: ResponsiveSliverGrid(
                      itemCount: _showAllSeries
                          ? content.allSeriesSorted.length
                          : content.allSeriesSorted.length.clamp(0, 20),
                      childAspectRatio: 0.7,
                      itemBuilder: (context, index) {
                        final series = content.allSeriesSorted[index];
                        return ContentCard(
                          title: series.name ?? 'Unbekannt',
                          subtitle: series.year,
                          imageUrl: series.cover,
                          icon: 'assets/icons/monitor-play.svg',
                          onTap: () => _openSeries(series),
                        );
                      },
                    ),
                  ),

                  // Show more button
                  if (!_showAllSeries && content.allSeriesSorted.length > 20)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _showAllSeries = true),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: colorScheme.outline.withAlpha(50),
                            ),
                          ),
                          child: Text(
                            'Alle ${content.allSeriesSorted.length} Serien anzeigen',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            SvgPicture.asset(
              'assets/icons/monitor-play.svg',
              width: 48,
              height: 48,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface.withAlpha(100),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Serien gefunden',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/plug.svg',
                width: 48,
                height: 48,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface.withAlpha(150),
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nicht verbunden',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gehe zu Profil und verbinde dich mit deinem IPTV-Server',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurface.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  final XTremeCodeSeriesItem series;
  final VoidCallback onTap;

  const _SeriesCard({
    required this.series,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metadata = ContentParser.parse(series.name ?? '');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withAlpha(25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: Stack(
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    color: colorScheme.onSurface.withAlpha(10),
                    child: series.cover != null
                        ? CachedNetworkImage(
                            imageUrl: series.cover!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                          )
                        : _buildPlaceholder(colorScheme),
                  ),
                  // Tags
                  if (metadata.isPopular || metadata.quality != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Row(
                        children: [
                          if (metadata.isPopular)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: SvgPicture.asset(
                                'assets/icons/flame.svg',
                                width: 12,
                                height: 12,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          if (metadata.quality != null) ...[
                            if (metadata.isPopular) const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                metadata.quality!,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                metadata.cleanName,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: SvgPicture.asset(
        'assets/icons/monitor-play.svg',
        width: 32,
        height: 32,
        colorFilter: ColorFilter.mode(
          colorScheme.onSurface.withAlpha(30),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
