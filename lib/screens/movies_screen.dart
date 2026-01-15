import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../models/favorite.dart';
import '../utils/content_parser.dart';
import '../utils/tv_utils.dart';
import 'movie_detail_screen.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  bool _showAllMovies = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final xtreamService = context.read<XtreamService>();
    if (xtreamService.isConnected) {
      await xtreamService.loadMoviesScreenContent();
    }
  }

  void _showMovieDetail(XTremeCodeVodItem movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailScreen(movie: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final content = xtreamService.moviesScreenContent;
    // Auch Preloading berücksichtigen
    final isLoading = xtreamService.isLoadingMovies || xtreamService.isPreloading;

    return Scaffold(
      body: !xtreamService.isConnected
          ? SafeArea(child: _buildNotConnected(context))
          : FocusTraversalGroup(
              policy: FlexibleVerticalFocusTraversalPolicy(),
              child: CustomScrollView(
                slivers: [
                // Sticky Glass Header
                StickyGlassHeader(
                  title: 'Filme',
                  subtitle: null,
                  iconPath: 'assets/icons/film-strip.svg',
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
                        height: 220, // Extra Platz für Fokus-Scale-Effekt
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none, // Verhindert Clipping bei Fokus-Scale
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: category.items.length,
                          itemBuilder: (context, index) {
                            final movie = category.items[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < category.items.length - 1 ? 12 : 0,
                              ),
                              child: _MovieCard(
                                movie: movie,
                                onTap: () => _showMovieDetail(movie),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // All Movies Section Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                      child: SectionHeader(
                        title: 'Alle Filme (A-Z)',
                        icon: 'assets/icons/list.svg',
                      ),
                    ),
                  ),

                  // All Movies Grid - mit Ladeindikator wenn noch leer
                  if (content.allMoviesSorted.isEmpty)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Filme werden geladen...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: ResponsiveSliverGrid(
                        itemCount: _showAllMovies
                            ? content.allMoviesSorted.length
                            : content.allMoviesSorted.length.clamp(0, 20),
                        childAspectRatio: 0.7,
                        itemBuilder: (context, index) {
                          final movie = content.allMoviesSorted[index];
                          return ContentCard(
                            title: movie.name ?? 'Unbekannt',
                            subtitle: movie.year,
                            imageUrl: movie.streamIcon,
                            icon: 'assets/icons/film-strip.svg',
                            onTap: () => _showMovieDetail(movie),
                          );
                        },
                      ),
                    ),

                  // Show more button
                  if (!_showAllMovies && content.allMoviesSorted.length > 20)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Focus(
                              child: Builder(
                                builder: (context) {
                                  final isFocused = Focus.of(context).hasFocus;
                                  return OutlinedButton(
                                    onPressed: () => setState(() => _showAllMovies = true),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: isFocused ? Colors.white : Colors.white.withAlpha(80),
                                        width: isFocused ? 3 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Alle Filme anzeigen',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
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
              'assets/icons/film-strip.svg',
              width: 48,
              height: 48,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface.withAlpha(100),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Filme gefunden',
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

class _MovieCard extends StatefulWidget {
  final XTremeCodeVodItem movie;
  final VoidCallback onTap;
  final bool autofocus;

  const _MovieCard({
    required this.movie,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<_MovieCard>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
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
    setState(() => _isFocused = hasFocus);
    if (hasFocus) {
      _scaleController.forward();
      // Smooth scroll zur fokussierten Card
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5, // Zentriert
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
          event.logicalKey == LogicalKeyboardKey.space) {
        widget.onTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final metadata = ContentParser.parse(widget.movie.name ?? '');
    final favoriteId = 'movie_${widget.movie.streamId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    return Focus(
      focusNode: _focusNode,
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
            width: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused ? Colors.white : colorScheme.outline.withAlpha(25),
                width: _isFocused ? 3 : 1,
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
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Full-size image
                  Positioned.fill(
                    child: Container(
                      color: colorScheme.onSurface.withAlpha(10),
                      child: widget.movie.streamIcon != null
                          ? CachedNetworkImage(
                              imageUrl: widget.movie.streamIcon!,
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
                  // Favorite button (top right)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        final favorite = Favorite.fromMovie(
                          streamId: widget.movie.streamId ?? 0,
                          title: widget.movie.name ?? '',
                          imageUrl: widget.movie.streamIcon,
                          extension: widget.movie.containerExtension,
                        );
                        xtreamService.toggleFavorite(favorite);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SvgPicture.asset(
                          isFavorite ? 'assets/icons/heart-fill.svg' : 'assets/icons/heart.svg',
                          width: 14,
                          height: 14,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tags (top left) - Quality + Language
                  if (metadata.quality != null || metadata.language != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      right: 40,
                      child: Row(
                        children: [
                          if (metadata.quality != null)
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
                          if (metadata.quality != null && metadata.language != null)
                            const SizedBox(width: 4),
                          if (metadata.language != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                metadata.language!,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
