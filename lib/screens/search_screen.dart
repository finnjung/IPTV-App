import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../widgets/content_card.dart';
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
            child: SizedBox(
              width: 140,
              child: ContentCard(
                title: movie.name ?? 'Unbekannt',
                subtitle: movie.year,
                imageUrl: movie.streamIcon,
                icon: 'assets/icons/film-strip.svg',
                onTap: () => _playMovie(movie),
              ),
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
            child: SizedBox(
              width: 140,
              child: ContentCard(
                title: series.name ?? 'Unbekannt',
                subtitle: series.year,
                imageUrl: series.cover,
                icon: 'assets/icons/monitor-play.svg',
                onTap: () => _openSeries(series),
              ),
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
            child: SizedBox(
              width: 180,
              child: ContentCard(
                title: stream.name ?? 'Unbekannt',
                subtitle: null,
                imageUrl: stream.streamIcon,
                icon: 'assets/icons/television.svg',
                isLive: true,
                onTap: () => _playLiveStream(stream),
              ),
            ),
          );
        },
      ),
    );
  }
}
