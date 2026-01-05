import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../models/watch_progress.dart';
import '../utils/content_parser.dart';
import '../widgets/sticky_glass_header.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    // Load content in background (will use cache if available)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContentIfNeeded();
    });
  }

  void _loadContentIfNeeded() {
    final xtreamService = context.read<XtreamService>();
    if (xtreamService.isConnected && xtreamService.startScreenContent == null) {
      xtreamService.loadStartScreenContent();
    }
  }

  Future<void> _refreshContent() async {
    final xtreamService = context.read<XtreamService>();
    await xtreamService.loadStartScreenContent(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final continueWatching = xtreamService.continueWatching;
    final content = xtreamService.startScreenContent;
    final isLoading = xtreamService.isStartScreenLoading;
    final preferredLanguage = xtreamService.preferredLanguage;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshContent,
        edgeOffset: 120,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Sticky Glass Header
            const StickyStartHeader(),

            // Continue Watching Section (always show if available)
              if (continueWatching.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: _SectionHeader(
                      title: 'Weiterschauen',
                      icon: 'assets/icons/play-circle.svg',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: continueWatching.length,
                      itemBuilder: (context, index) {
                        final item = continueWatching[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < continueWatching.length - 1 ? 12 : 0,
                          ),
                          child: _ContinueWatchingCard(item: item),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],

              // Loading indicator (full screen when no content yet)
              if (isLoading && content == null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: colorScheme.onSurface.withAlpha(100),
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Inhalte werden geladen...',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Content sections (when loaded)
              if (content != null) ...[
                // Popular Movies Section
                if (content.popularMovies.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: _SectionHeader(
                        title: 'Beliebte Filme',
                        icon: 'assets/icons/flame.svg',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: content.popularMovies.length,
                        itemBuilder: (context, index) {
                          final movie = content.popularMovies[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index < content.popularMovies.length - 1 ? 12 : 0,
                            ),
                            child: _MovieCard(movie: movie),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Popular Series Section
                if (content.popularSeries.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                      child: _SectionHeader(
                        title: 'Beliebte Serien',
                        icon: 'assets/icons/flame.svg',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: content.popularSeries.length,
                        itemBuilder: (context, index) {
                          final series = content.popularSeries[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index < content.popularSeries.length - 1 ? 12 : 0,
                            ),
                            child: _SeriesCard(series: series),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Recommended Movies Section (by Language)
                if (content.recommendedMovies.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                      child: _SectionHeader(
                        title: preferredLanguage != null
                            ? 'Filme auf ${ContentParser.languageCodes[preferredLanguage] ?? preferredLanguage}'
                            : 'Filme für dich',
                        icon: 'assets/icons/film-strip.svg',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: content.recommendedMovies.length,
                        itemBuilder: (context, index) {
                          final movie = content.recommendedMovies[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index < content.recommendedMovies.length - 1 ? 12 : 0,
                            ),
                            child: _MovieCard(movie: movie),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Recommended Series Section (by Language)
                if (content.recommendedSeries.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                      child: _SectionHeader(
                        title: preferredLanguage != null
                            ? 'Serien auf ${ContentParser.languageCodes[preferredLanguage] ?? preferredLanguage}'
                            : 'Serien für dich',
                        icon: 'assets/icons/monitor-play.svg',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: content.recommendedSeries.length,
                        itemBuilder: (context, index) {
                          final series = content.recommendedSeries[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index < content.recommendedSeries.length - 1 ? 12 : 0,
                            ),
                            child: _SeriesCard(series: series),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],

              // Empty state if nothing to show and not loading
              if (!isLoading &&
                  content != null &&
                  content.isEmpty &&
                  continueWatching.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(colorScheme),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withAlpha(25),
        ),
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/icons/play-circle.svg',
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(
              colorScheme.onSurface.withAlpha(80),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Noch nichts verfügbar',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stöbere in den Tabs nach Filmen und Serien.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: colorScheme.onSurface.withAlpha(120),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final XTremeCodeVodItem movie;

  const _MovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.read<XtreamService>();
    final metadata = ContentParser.parse(movie.name ?? '');

    return GestureDetector(
      onTap: () {
        final streamUrl = xtreamService.getMovieUrl(movie.streamId ?? 0);
        if (streamUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                title: metadata.cleanName,
                streamUrl: streamUrl,
                contentId: 'movie_${movie.streamId}',
                imageUrl: movie.streamIcon,
                contentType: ContentType.movie,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withAlpha(25),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              // Full-size image
              Positioned.fill(
                child: Container(
                  color: colorScheme.onSurface.withAlpha(10),
                  child: movie.streamIcon != null
                      ? CachedNetworkImage(
                          imageUrl: movie.streamIcon!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                        )
                      : _buildPlaceholder(colorScheme),
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withAlpha(100),
                        Colors.black.withAlpha(200),
                        Colors.black.withAlpha(230),
                      ],
                      stops: const [0.0, 0.45, 0.65, 0.85, 1.0],
                    ),
                  ),
                ),
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
              // Title at bottom
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  metadata.cleanName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: SvgPicture.asset(
        'assets/icons/film-strip.svg',
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

class _SeriesCard extends StatelessWidget {
  final XTremeCodeSeriesItem series;

  const _SeriesCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metadata = ContentParser.parse(series.name ?? '');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SeriesDetailScreen(series: series),
          ),
        );
      },
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withAlpha(25),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              // Full-size image
              Positioned.fill(
                child: Container(
                  color: colorScheme.onSurface.withAlpha(10),
                  child: series.cover != null
                      ? CachedNetworkImage(
                          imageUrl: series.cover!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                        )
                      : _buildPlaceholder(colorScheme),
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withAlpha(100),
                        Colors.black.withAlpha(200),
                        Colors.black.withAlpha(230),
                      ],
                      stops: const [0.0, 0.45, 0.65, 0.85, 1.0],
                    ),
                  ),
                ),
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
              // Title at bottom
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  metadata.cleanName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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

class _ContinueWatchingCard extends StatelessWidget {
  final WatchProgress item;

  const _ContinueWatchingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Clean the title in case it was saved before the parser was improved
    final cleanTitle = ContentParser.parse(item.title).cleanName;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              title: cleanTitle,
              subtitle: item.subtitle,
              streamUrl: item.streamUrl,
              contentId: item.id,
              imageUrl: item.imageUrl,
              contentType: item.contentType,
            ),
          ),
        );
      },
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outline.withAlpha(25),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              // Full-size image
              Positioned.fill(
                child: Container(
                  color: colorScheme.onSurface.withAlpha(10),
                  child: item.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                        )
                      : _buildPlaceholder(colorScheme),
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(80),
                        Colors.black.withAlpha(180),
                        Colors.black.withAlpha(220),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // Play Button
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 60,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/play.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
              // Info at bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.subtitle != null) ...[
                          Expanded(
                            child: Text(
                              item.subtitle!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withAlpha(180),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          item.remainingTime,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Progress Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: item.progress,
                  backgroundColor: Colors.black38,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.onSurface.withAlpha(10),
      child: Center(
        child: SvgPicture.asset(
          item.contentType == ContentType.movie
              ? 'assets/icons/film-strip.svg'
              : 'assets/icons/monitor-play.svg',
          width: 32,
          height: 32,
          colorFilter: ColorFilter.mode(
            colorScheme.onSurface.withAlpha(50),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SvgPicture.asset(
          icon,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            colorScheme.onSurface.withAlpha(150),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
