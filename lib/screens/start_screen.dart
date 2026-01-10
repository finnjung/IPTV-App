import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../models/watch_progress.dart';
import '../models/favorite.dart';
import '../utils/content_parser.dart';
import '../widgets/sticky_glass_header.dart';
import '../widgets/hero_banner.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'movie_detail_screen.dart';

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

  bool _isDesktopPlatform() {
    if (kIsWeb) return true;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  bool _useDesktopLayout(BuildContext context) {
    return _isDesktopPlatform() && MediaQuery.of(context).size.width >= 768;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final continueWatching = xtreamService.continueWatching;
    final favorites = xtreamService.favorites;
    final content = xtreamService.startScreenContent;
    // Auch Preloading berücksichtigen
    final isLoading = xtreamService.isStartScreenLoading || xtreamService.isPreloading;
    final preferredLanguage = xtreamService.preferredLanguage;
    final isDesktop = _useDesktopLayout(context);

    return Scaffold(
      body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // Hero Banner (wenn Spotlight verfügbar)
            if (content?.spotlight != null)
              SliverToBoxAdapter(
                child: _buildHeroBanner(content!.spotlight!, xtreamService),
              )
            else if (!isDesktop)
              // Sticky Glass Header als Fallback (nur Mobile - Desktop hat das Overlay)
              const StickyStartHeader()
            else
              // Desktop ohne Spotlight: Nur Padding für das Overlay
              const SliverToBoxAdapter(child: SizedBox(height: 100)),

            // "Das gefällt dir bestimmt" Section - ganz oben nach Banner
            if (content != null)
              ..._buildCuratedPopularSectionOnly(content),

            // Continue Watching Section
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

            // Favorites Section (after Continue Watching) - always rendered for smooth animation
            SliverToBoxAdapter(
              child: _AnimatedFavoritesSection(favorites: favorites),
            ),

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

              // Dynamic Content Sections (in täglicher Reihenfolge)
              if (content != null)
                ..._buildDynamicSections(content, preferredLanguage),

              // Empty state if nothing to show and not loading
              if (!isLoading &&
                  content != null &&
                  content.isEmpty &&
                  continueWatching.isEmpty &&
                  favorites.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(colorScheme),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
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

  /// Baut das Hero-Banner
  Widget _buildHeroBanner(SpotlightContent spotlight, XtreamService xtreamService) {
    return HeroBanner(
      title: spotlight.name,
      imageUrl: spotlight.imageUrl,
      quality: spotlight.quality,
      language: spotlight.language,
      category: spotlight.curatedTitle.category,
      onPlay: () {
        if (spotlight.isMovie) {
          final movie = spotlight.originalItem as XTremeCodeVodItem;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailScreen(movie: movie),
            ),
          );
        } else {
          final series = spotlight.originalItem as XTremeCodeSeriesItem;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeriesDetailScreen(series: series),
            ),
          );
        }
      },
    );
  }

  /// Baut dynamische Content-Sections basierend auf täglicher Reihenfolge
  List<Widget> _buildDynamicSections(StartScreenContent content, String? preferredLanguage) {
    final sections = <Widget>[];

    for (final section in content.sectionOrder) {
      switch (section) {
        case StartScreenSection.continueWatching:
        case StartScreenSection.favorites:
        case StartScreenSection.curatedPopular:
          // Diese werden separat oben gehandhabt (curatedPopular ganz oben nach Banner)
          break;

        case StartScreenSection.curatedKids:
          if (content.curatedKids.isNotEmpty) {
            sections.addAll(_buildCuratedKidsSection(content));
          }
          break;

        case StartScreenSection.thrillerSeries:
          if (content.thrillerSeries.isNotEmpty) {
            sections.addAll(_buildThrillerSeriesSection(content));
          }
          break;

        case StartScreenSection.actionMovies:
          if (content.actionMovies.isNotEmpty) {
            sections.addAll(_buildActionMoviesSection(content));
          }
          break;

        case StartScreenSection.allMovies:
          if (content.allMovies.isNotEmpty) {
            sections.addAll(_buildAllMoviesSection(content));
          }
          break;

        case StartScreenSection.allSeries:
          if (content.allSeries.isNotEmpty) {
            sections.addAll(_buildAllSeriesSection(content));
          }
          break;
      }
    }

    return sections;
  }

  /// Baut nur die "Das gefällt dir bestimmt" Section (wird ganz oben angezeigt)
  List<Widget> _buildCuratedPopularSectionOnly(StartScreenContent content) {
    if (content.curatedMovies.isNotEmpty || content.curatedSeries.isNotEmpty) {
      return _buildCuratedPopularSection(content);
    }
    return [];
  }

  List<Widget> _buildCuratedPopularSection(StartScreenContent content) {
    // Mische Filme und Serien, bevorzuge nach Match-Score
    final allCurated = <dynamic>[...content.curatedMovies, ...content.curatedSeries];

    // Sortiere nach Match-Score
    allCurated.sort((a, b) {
      final nameA = a is XTremeCodeVodItem ? a.name : (a as XTremeCodeSeriesItem).name;
      final nameB = b is XTremeCodeVodItem ? b.name : (b as XTremeCodeSeriesItem).name;
      final metaA = ContentParser.parse(nameA ?? '');
      final metaB = ContentParser.parse(nameB ?? '');
      return metaB.curatedMatchScore.compareTo(metaA.curatedMatchScore);
    });

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: _SectionHeader(
            title: 'Das gefällt dir bestimmt',
            icon: 'assets/icons/star.svg',
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: allCurated.take(20).length,
            itemBuilder: (context, index) {
              final item = allCurated[index];
              return Padding(
                padding: EdgeInsets.only(right: index < 19 ? 12 : 0),
                child: item is XTremeCodeVodItem
                    ? _MovieCard(movie: item)
                    : _SeriesCard(series: item as XTremeCodeSeriesItem),
              );
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildCuratedKidsSection(StartScreenContent content) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: _SectionHeader(
            title: 'Für die Kleinen',
            icon: 'assets/icons/heart.svg',
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: content.curatedKids.length,
            itemBuilder: (context, index) {
              final item = content.curatedKids[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < content.curatedKids.length - 1 ? 12 : 0,
                ),
                child: item is XTremeCodeVodItem
                    ? _MovieCard(movie: item)
                    : _SeriesCard(series: item as XTremeCodeSeriesItem),
              );
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildThrillerSeriesSection(StartScreenContent content) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: _SectionHeader(
            title: 'Spannende Serien',
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
            itemCount: content.thrillerSeries.length,
            itemBuilder: (context, index) {
              final series = content.thrillerSeries[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < content.thrillerSeries.length - 1 ? 12 : 0,
                ),
                child: _SeriesCard(series: series),
              );
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildActionMoviesSection(StartScreenContent content) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: _SectionHeader(
            title: 'Action Filme',
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
            itemCount: content.actionMovies.length,
            itemBuilder: (context, index) {
              final movie = content.actionMovies[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < content.actionMovies.length - 1 ? 12 : 0,
                ),
                child: _MovieCard(movie: movie),
              );
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAllMoviesSection(StartScreenContent content) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
          child: _SectionHeader(
            title: 'Alle Filme',
            icon: 'assets/icons/film-strip.svg',
            subtitle: '${content.allMovies.length} Titel',
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: content.allMovies.length,
            itemBuilder: (context, index) {
              final movie = content.allMovies[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < content.allMovies.length - 1 ? 12 : 0,
                ),
                child: _MovieCard(movie: movie),
              );
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAllSeriesSection(StartScreenContent content) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: _SectionHeader(
            title: 'Alle Serien',
            icon: 'assets/icons/monitor-play.svg',
            subtitle: '${content.allSeries.length} Titel',
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: content.allSeries.length,
            itemBuilder: (context, index) {
              final series = content.allSeries[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < content.allSeries.length - 1 ? 12 : 0,
                ),
                child: _SeriesCard(series: series),
              );
            },
          ),
        ),
      ),
    ];
  }
}

class _MovieCard extends StatelessWidget {
  final XTremeCodeVodItem movie;

  const _MovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metadata = ContentParser.parse(movie.name ?? '');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailScreen(movie: movie),
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
              // Quality Tag
              if (metadata.quality != null)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
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
              // Quality Tag
              if (metadata.quality != null)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
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

class _AnimatedFavoritesSection extends StatelessWidget {
  final List<Favorite> favorites;

  const _AnimatedFavoritesSection({required this.favorites});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: favorites.isEmpty
          ? const SizedBox.shrink()
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _SectionHeader(
                    title: 'Favoriten',
                    icon: 'assets/icons/heart-fill.svg',
                  ),
                ),
                SizedBox(
                  height: 80,
                  child: _AnimatedFavoritesList(favorites: favorites),
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}

class _AnimatedFavoritesList extends StatefulWidget {
  final List<Favorite> favorites;

  const _AnimatedFavoritesList({required this.favorites});

  @override
  State<_AnimatedFavoritesList> createState() => _AnimatedFavoritesListState();
}

class _AnimatedFavoritesListState extends State<_AnimatedFavoritesList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<Favorite> _internalList;

  @override
  void initState() {
    super.initState();
    _internalList = List.from(widget.favorites);
  }

  @override
  void didUpdateWidget(_AnimatedFavoritesList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Find removed items
    final removedItems = _internalList.where(
      (item) => !widget.favorites.any((f) => f.id == item.id)
    ).toList();

    // Find added items
    final addedItems = widget.favorites.where(
      (item) => !_internalList.any((f) => f.id == item.id)
    ).toList();

    // Animate removals
    for (final removed in removedItems) {
      final index = _internalList.indexOf(removed);
      if (index != -1) {
        _internalList.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _buildAnimatedItem(removed, animation),
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    // Handle additions
    for (final added in addedItems) {
      // Find correct position (favorites are sorted by addedAt descending)
      int insertIndex = 0;
      for (int i = 0; i < _internalList.length; i++) {
        if (added.addedAt.isAfter(_internalList[i].addedAt)) {
          insertIndex = i;
          break;
        }
        insertIndex = i + 1;
      }
      _internalList.insert(insertIndex, added);
      _listKey.currentState?.insertItem(
        insertIndex,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Widget _buildAnimatedItem(Favorite favorite, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      axis: Axis.horizontal,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _FavoriteCard(
            favorite: favorite,
            onRemove: () {}, // Disabled during animation
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final xtreamService = context.read<XtreamService>();

    return AnimatedList(
      key: _listKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      initialItemCount: _internalList.length,
      itemBuilder: (context, index, animation) {
        final favorite = _internalList[index];
        return SizeTransition(
          sizeFactor: animation,
          axis: Axis.horizontal,
          child: FadeTransition(
            opacity: animation,
            child: Padding(
              padding: EdgeInsets.only(
                right: index < _internalList.length - 1 ? 12 : 0,
              ),
              child: _FavoriteCard(
                favorite: favorite,
                onRemove: () => xtreamService.removeFavorite(favorite.id),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Favorite favorite;
  final VoidCallback onRemove;

  const _FavoriteCard({required this.favorite, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.read<XtreamService>();

    return GestureDetector(
      onTap: () => _navigateToContent(context, xtreamService),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outline.withAlpha(25),
          ),
        ),
        child: Row(
          children: [
            // Small image/icon on the left
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withAlpha(15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
                child: favorite.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: favorite.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                      )
                    : _buildPlaceholder(colorScheme),
              ),
            ),
            // Content on the right
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Badge + Heart
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTypeColor(),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getTypeLabel(),
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onRemove,
                          child: SvgPicture.asset(
                            'assets/icons/heart-fill.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface.withAlpha(150),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Title
                    Expanded(
                      child: Text(
                        ContentParser.parse(favorite.title).cleanName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (favorite.contentType) {
      case ContentType.movie:
        return Colors.blue.shade700;
      case ContentType.series:
        return Colors.purple.shade700;
      case ContentType.live:
        return Colors.red.shade700;
    }
  }

  String _getTypeLabel() {
    switch (favorite.contentType) {
      case ContentType.movie:
        return 'Film';
      case ContentType.series:
        return 'Serie';
      case ContentType.live:
        return 'Live';
    }
  }

  void _navigateToContent(BuildContext context, XtreamService xtreamService) {
    switch (favorite.contentType) {
      case ContentType.movie:
        // Navigate to movie detail screen using MovieDetailScreenFromFavorite
        if (favorite.streamId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailScreenFromFavorite(
                streamId: favorite.streamId!,
                movieTitle: favorite.title,
                moviePoster: favorite.imageUrl,
                containerExtension: favorite.extension,
              ),
            ),
          );
        }
        break;
      case ContentType.series:
        // Navigate to series detail using SeriesDetailScreenFromFavorite
        if (favorite.seriesId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeriesDetailScreenFromFavorite(
                seriesId: favorite.seriesId!,
                seriesName: favorite.title,
                seriesCover: favorite.imageUrl,
              ),
            ),
          );
        }
        break;
      case ContentType.live:
        // Use direct URL generation for live streams
        final streamUrl = xtreamService.client?.streamUrl(
          favorite.streamId ?? 0,
          ['ts', 'm3u8'],
        );
        if (streamUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                title: ContentParser.parse(favorite.title).cleanName,
                streamUrl: streamUrl,
                contentId: favorite.id,
                imageUrl: favorite.imageUrl,
                contentType: ContentType.live,
              ),
            ),
          );
        }
        break;
    }
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    String iconPath;
    switch (favorite.contentType) {
      case ContentType.movie:
        iconPath = 'assets/icons/film-strip.svg';
        break;
      case ContentType.series:
        iconPath = 'assets/icons/monitor-play.svg';
        break;
      case ContentType.live:
        iconPath = 'assets/icons/television.svg';
        break;
    }

    return Center(
      child: SvgPicture.asset(
        iconPath,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String icon;
  final String? subtitle;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.subtitle,
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
          child: Row(
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurface.withAlpha(100),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
