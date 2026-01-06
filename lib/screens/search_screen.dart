import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../models/favorite.dart';
import '../models/watch_progress.dart';
import '../utils/content_parser.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  SearchResults _results = SearchResults.empty();
  bool _isSearching = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query == _lastQuery) return;
    _lastQuery = query;

    if (query.length < 2) {
      setState(() {
        _results = SearchResults.empty();
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final xtreamService = context.read<XtreamService>();
    final results = await xtreamService.search(query);

    if (mounted && query == _lastQuery) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  void _playMovie(XTremeCodeVodItem movie) {
    final xtreamService = context.read<XtreamService>();
    final url = xtreamService.getMovieUrl(
      movie.streamId ?? 0,
      container: movie.containerExtension ?? 'mp4',
    );

    if (url != null) {
      final metadata = ContentParser.parse(movie.name ?? 'Film');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: metadata.cleanName,
            subtitle: movie.year,
            streamUrl: url,
            contentId: 'movie_${movie.streamId}',
            imageUrl: movie.streamIcon,
            contentType: ContentType.movie,
          ),
        ),
      );
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

  void _playLiveStream(XTremeCodeLiveStreamItem stream) {
    final xtreamService = context.read<XtreamService>();
    final url = xtreamService.getLiveStreamUrl(stream);

    if (url != null) {
      final metadata = ContentParser.parse(stream.name ?? 'Live TV');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: metadata.cleanName,
            subtitle: null,
            streamUrl: url,
            contentId: 'live_${stream.streamId}',
            imageUrl: stream.streamIcon,
            contentType: ContentType.live,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header mit Suchfeld
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/arrow-left.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Suche',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Suchfeld
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Filme, Serien, Live TV...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          color: colorScheme.onSurface.withAlpha(100),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(14),
                          child: SvgPicture.asset(
                            'assets/icons/magnifying-glass.svg',
                            width: 22,
                            height: 22,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface.withAlpha(150),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: SvgPicture.asset(
                                    'assets/icons/x.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: ColorFilter.mode(
                                      colorScheme.onSurface.withAlpha(150),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Ergebnisse
            Expanded(
              child: _buildContent(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      return _buildEmptyState(
        colorScheme,
        'assets/icons/magnifying-glass.svg',
        'Suche starten',
        'Gib mindestens 2 Zeichen ein',
      );
    }

    if (_searchController.text.length < 2) {
      return _buildEmptyState(
        colorScheme,
        'assets/icons/magnifying-glass.svg',
        'Weiter tippen...',
        'Gib mindestens 2 Zeichen ein',
      );
    }

    if (_results.isEmpty) {
      return _buildEmptyState(
        colorScheme,
        'assets/icons/x.svg',
        'Keine Ergebnisse',
        'Versuche einen anderen Suchbegriff',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (_results.movies.isNotEmpty)
          _buildSection(
            colorScheme,
            'Filme',
            '${_results.movies.length}',
            'assets/icons/film-strip.svg',
            _buildMoviesList(),
          ),
        if (_results.series.isNotEmpty)
          _buildSection(
            colorScheme,
            'Serien',
            '${_results.series.length}',
            'assets/icons/monitor-play.svg',
            _buildSeriesList(),
          ),
        if (_results.liveStreams.isNotEmpty)
          _buildSection(
            colorScheme,
            'Live TV',
            '${_results.liveStreams.length}',
            'assets/icons/broadcast.svg',
            _buildLiveStreamsList(),
          ),
      ],
    );
  }

  Widget _buildEmptyState(
    ColorScheme colorScheme,
    String icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            icon,
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(
              colorScheme.onSurface.withAlpha(100),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    ColorScheme colorScheme,
    String title,
    String count,
    String icon,
    Widget content,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
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
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ),
            ],
          ),
        ),
        content,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMoviesList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _results.movies.length,
        itemBuilder: (context, index) {
          final movie = _results.movies[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _SearchMovieCard(
              movie: movie,
              onTap: () => _playMovie(movie),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeriesList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _results.series.length,
        itemBuilder: (context, index) {
          final series = _results.series[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _SearchSeriesCard(
              series: series,
              onTap: () => _openSeries(series),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveStreamsList() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _results.liveStreams.length,
        itemBuilder: (context, index) {
          final stream = _results.liveStreams[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _SearchLiveCard(
              stream: stream,
              onTap: () => _playLiveStream(stream),
            ),
          );
        },
      ),
    );
  }
}

// Search Movie Card with Favorite Button
class _SearchMovieCard extends StatelessWidget {
  final XTremeCodeVodItem movie;
  final VoidCallback onTap;

  const _SearchMovieCard({required this.movie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final metadata = ContentParser.parse(movie.name ?? '');
    final favoriteId = 'movie_${movie.streamId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withAlpha(25)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(
                child: movie.streamIcon != null
                    ? CachedNetworkImage(
                        imageUrl: movie.streamIcon!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                      )
                    : _buildPlaceholder(colorScheme),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(200),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Favorite button
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    xtreamService.toggleFavorite(Favorite.fromMovie(
                      streamId: movie.streamId ?? 0,
                      title: movie.name ?? '',
                      imageUrl: movie.streamIcon,
                      extension: movie.containerExtension,
                    ));
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
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
              // Quality badge
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
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              // Title
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.cleanName,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (movie.year != null)
                      Text(
                        movie.year!,
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
                      ),
                  ],
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
          'assets/icons/film-strip.svg',
          width: 32,
          height: 32,
          colorFilter: ColorFilter.mode(colorScheme.onSurface.withAlpha(30), BlendMode.srcIn),
        ),
      ),
    );
  }
}

// Search Series Card with Favorite Button
class _SearchSeriesCard extends StatelessWidget {
  final XTremeCodeSeriesItem series;
  final VoidCallback onTap;

  const _SearchSeriesCard({required this.series, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final metadata = ContentParser.parse(series.name ?? '');
    final favoriteId = 'series_${series.seriesId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withAlpha(25)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(
                child: series.cover != null
                    ? CachedNetworkImage(
                        imageUrl: series.cover!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                      )
                    : _buildPlaceholder(colorScheme),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(200),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Favorite button
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    xtreamService.toggleFavorite(Favorite.fromSeries(
                      seriesId: series.seriesId ?? 0,
                      title: series.name ?? '',
                      imageUrl: series.cover,
                    ));
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
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
              // Title
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.cleanName,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (series.year != null)
                      Text(
                        series.year!,
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
                      ),
                  ],
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
          'assets/icons/monitor-play.svg',
          width: 32,
          height: 32,
          colorFilter: ColorFilter.mode(colorScheme.onSurface.withAlpha(30), BlendMode.srcIn),
        ),
      ),
    );
  }
}

// Search Live Card with Favorite Button
class _SearchLiveCard extends StatelessWidget {
  final XTremeCodeLiveStreamItem stream;
  final VoidCallback onTap;

  const _SearchLiveCard({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final metadata = ContentParser.parse(stream.name ?? '');
    final favoriteId = 'live_${stream.streamId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withAlpha(25)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(
                child: stream.streamIcon != null
                    ? CachedNetworkImage(
                        imageUrl: stream.streamIcon!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                      )
                    : _buildPlaceholder(colorScheme),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(200),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
              ),
              // LIVE badge
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              // Favorite button
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    xtreamService.toggleFavorite(Favorite.fromLiveStream(
                      streamId: stream.streamId ?? 0,
                      title: stream.name ?? '',
                      imageUrl: stream.streamIcon,
                    ));
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
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
              // Title
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  metadata.cleanName,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
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
    return Container(
      color: colorScheme.onSurface.withAlpha(10),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/television.svg',
          width: 28,
          height: 28,
          colorFilter: ColorFilter.mode(colorScheme.onSurface.withAlpha(30), BlendMode.srcIn),
        ),
      ),
    );
  }
}
