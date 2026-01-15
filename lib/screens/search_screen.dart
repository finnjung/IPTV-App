import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../models/favorite.dart';
import '../models/watch_progress.dart';
import '../utils/content_parser.dart';
import '../utils/tv_utils.dart';
import '../widgets/tv_keyboard.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _focusNode;
  Timer? _debounce;
  SearchResults _results = SearchResults.empty();
  bool _isSearching = false;
  String _lastQuery = '';
  bool _showTvKeyboard = false;

  // Discovery data
  List<XTremeCodeVodItem> _suggestedMovies = [];
  List<XTremeCodeSeriesItem> _suggestedSeries = [];

  // Check if running on Android TV or Fire TV
  // Uses centralized TV detection from TvUtils
  bool get _isTvDevice => TvUtils.useTvInterface;

  static const List<String> _quickSearchTerms = [
    'Action',
    'Comedy',
    'Drama',
    'Horror',
    'Thriller',
    'Sci-Fi',
    'Romance',
    'Animation',
    'Documentary',
    'Crime',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize focus node - key event handling is done in build method with context
    _focusNode = FocusNode();
    // Listen to search controller changes for TV keyboard
    _searchController.addListener(_onSearchControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isTvDevice) {
        _focusNode.requestFocus();
      }
      _loadDiscoveryContent();
    });
  }

  void _onSearchControllerChanged() {
    // Trigger search when typing on TV keyboard
    if (_showTvKeyboard) {
      setState(() {});
      _onSearchChanged(_searchController.text);
    }
  }

  void _loadDiscoveryContent() {
    final xtreamService = context.read<XtreamService>();
    final content = xtreamService.startScreenContent;

    if (content != null) {
      final random = Random();

      // Get random movies from curated or all movies
      final movieSource = content.curatedMovies.isNotEmpty
          ? content.curatedMovies
          : content.allMovies;
      if (movieSource.isNotEmpty) {
        final shuffled = List<XTremeCodeVodItem>.from(movieSource)..shuffle(random);
        _suggestedMovies = shuffled.take(10).toList();
      }

      // Get random series from curated or all series
      final seriesSource = content.curatedSeries.isNotEmpty
          ? content.curatedSeries
          : content.allSeries;
      if (seriesSource.isNotEmpty) {
        final shuffled = List<XTremeCodeSeriesItem>.from(seriesSource)..shuffle(random);
        _suggestedSeries = shuffled.take(10).toList();
      }

      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchControllerChanged);
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

      // Zur Suchhistorie hinzufügen wenn Ergebnisse gefunden wurden
      if (!results.isEmpty) {
        xtreamService.addToSearchHistory(query);
      }
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

    // Extra top padding für macOS Titelleiste
    final isMacOS = !kIsWeb && Platform.isMacOS;
    final topPadding = isMacOS ? 28.0 : 0.0;

    final safePadding = MediaQuery.of(context).padding.top;
    final headerHeight = 160.0 + topPadding + safePadding;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Stack(
          children: [
            // Content (scrollt unter dem Header)
            _buildContentWithPadding(colorScheme, headerHeight),

            // Header mit Gradient (schwebt über dem Content)
            Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor,
                    bgColor,
                    bgColor.withAlpha(0),
                  ],
                  stops: const [0.0, 0.85, 1.0],
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, safePadding + 20 + topPadding, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(0),
                          child: Focus(
                            child: Builder(
                              builder: (context) {
                                final isFocused = Focus.of(context).hasFocus;
                                return GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isFocused
                                          ? Colors.white
                                          : colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isFocused
                                          ? Border.all(color: Colors.white, width: 2)
                                          : null,
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/icons/arrow-left.svg',
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        isFocused ? Colors.black : colorScheme.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                );
                              },
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
                    // Suchfeld - TV-kompatibel
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: _buildSearchField(colorScheme),
                    ),
                    // TV Keyboard
                    if (_isTvDevice && _showTvKeyboard) ...[
                      const SizedBox(height: 16),
                      TvKeyboard(
                        controller: _searchController,
                        hintText: 'Suchbegriff eingeben...',
                        onSubmit: () {
                          setState(() => _showTvKeyboard = false);
                          _onSearchChanged(_searchController.text);
                        },
                        onClose: () {
                          setState(() => _showTvKeyboard = false);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    if (_isTvDevice) {
      // TV: Fokussierbarer Container statt TextField
      return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              setState(() => _showTvKeyboard = true);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: () => setState(() => _showTvKeyboard = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: (isFocused || _showTvKeyboard)
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/magnifying-glass.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withAlpha(150),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Filme, Serien, Live TV...'
                            : _searchController.text,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: _searchController.text.isEmpty
                              ? colorScheme.onSurface.withAlpha(100)
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
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
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      // Non-TV: TextField mit Shortcuts für Pfeiltasten-Navigation
      return Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
        },
        child: Container(
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
      );
    }
  }

  Widget _buildContentWithPadding(ColorScheme colorScheme, double topPadding) {
    if (_isSearching) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show discovery content when search is empty
    if (_searchController.text.isEmpty) {
      return _buildDiscoveryContentScrollable(colorScheme, topPadding);
    }

    if (_searchController.text.length < 2) {
      return _buildDiscoveryContentScrollable(colorScheme, topPadding);
    }

    if (_results.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: _buildEmptyState(
          colorScheme,
          'assets/icons/x.svg',
          'Keine Ergebnisse',
          'Versuche einen anderen Suchbegriff',
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(top: topPadding, bottom: 40),
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

  Widget _buildDiscoveryContentScrollable(ColorScheme colorScheme, double topPadding) {
    final xtreamService = context.watch<XtreamService>();
    final searchHistory = xtreamService.searchHistory;

    return ListView(
      padding: EdgeInsets.only(top: topPadding, bottom: 40),
      children: [
        // Search History (mit Animation beim Ausblenden)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: child,
              ),
            );
          },
          child: searchHistory.isNotEmpty
              ? FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: _buildSearchHistorySection(colorScheme, searchHistory),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),

        // Quick Search Chips
        FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: _buildQuickSearchSection(colorScheme),
        ),

        // Suggested Movies
        if (_suggestedMovies.isNotEmpty)
          FocusTraversalOrder(
            order: const NumericFocusOrder(4),
            child: _buildDiscoverySection(
              colorScheme,
              'Entdecke Filme',
              'assets/icons/film-strip.svg',
              _buildSuggestedMovies(),
            ),
          ),

        // Suggested Series
        if (_suggestedSeries.isNotEmpty)
          FocusTraversalOrder(
            order: const NumericFocusOrder(5),
            child: _buildDiscoverySection(
              colorScheme,
              'Entdecke Serien',
              'assets/icons/monitor-play.svg',
              _buildSuggestedSeries(),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchHistorySection(ColorScheme colorScheme, List<String> history) {
    return Padding(
      key: const ValueKey('search_history'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/clock-counter-clockwise.svg',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface.withAlpha(150),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Zuletzt gesucht',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  context.read<XtreamService>().clearSearchHistory();
                },
                child: Text(
                  'Löschen',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: history.map((term) {
              return Builder(
                builder: (chipContext) {
                  return Focus(
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (chipContext.mounted) {
                            Scrollable.ensureVisible(
                              chipContext,
                              alignment: 0.3,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        });
                      }
                    },
                    child: Builder(
                      builder: (ctx) {
                        final isFocused = Focus.of(ctx).hasFocus;
                        return GestureDetector(
                          onTap: () {
                            _searchController.text = term;
                            _onSearchChanged(term);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.only(left: 14, right: 6, top: 8, bottom: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: isFocused
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  term,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    context.read<XtreamService>().removeFromSearchHistory(term);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: SvgPicture.asset(
                                      'assets/icons/x.svg',
                                      width: 12,
                                      height: 12,
                                      colorFilter: ColorFilter.mode(
                                        colorScheme.onSurface.withAlpha(100),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSearchSection(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/sparkle.svg',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Schnellsuche',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickSearchTerms.map((term) {
              return Builder(
                builder: (chipContext) {
                  return Focus(
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (chipContext.mounted) {
                            Scrollable.ensureVisible(
                              chipContext,
                              alignment: 0.3,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        });
                      }
                    },
                    child: Builder(
                      builder: (ctx) {
                        final isFocused = Focus.of(ctx).hasFocus;
                        return GestureDetector(
                          onTap: () {
                            _searchController.text = term;
                            _onSearchChanged(term);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary.withAlpha(20),
                                  colorScheme.secondary.withAlpha(15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isFocused ? Colors.white : colorScheme.primary.withAlpha(40),
                                width: isFocused ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              term,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySection(
    ColorScheme colorScheme,
    String title,
    String icon,
    Widget content,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              SvgPicture.asset(
                icon,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface.withAlpha(150),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        content,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSuggestedMovies() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _suggestedMovies.length,
        itemBuilder: (context, index) {
          final movie = _suggestedMovies[index];
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

  Widget _buildSuggestedSeries() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _suggestedSeries.length,
        itemBuilder: (context, index) {
          final series = _suggestedSeries[index];
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
class _SearchMovieCard extends StatefulWidget {
  final XTremeCodeVodItem movie;
  final VoidCallback onTap;

  const _SearchMovieCard({required this.movie, required this.onTap});

  @override
  State<_SearchMovieCard> createState() => _SearchMovieCardState();
}

class _SearchMovieCardState extends State<_SearchMovieCard>
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
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
            width: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused ? Colors.white : colorScheme.outline.withAlpha(25),
                width: _isFocused ? 3 : 1,
              ),
              boxShadow: _isFocused
                  ? [BoxShadow(color: Colors.white.withAlpha(50), blurRadius: 16, spreadRadius: 2)]
                  : null,
            ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.movie.streamIcon != null
                    ? CachedNetworkImage(
                        imageUrl: widget.movie.streamIcon!,
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
                      streamId: widget.movie.streamId ?? 0,
                      title: widget.movie.name ?? '',
                      imageUrl: widget.movie.streamIcon,
                      extension: widget.movie.containerExtension,
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
              // Quality + Language badges
              if (metadata.quality != null || metadata.language != null)
                Positioned(
                  top: 6,
                  left: 6,
                  right: 40, // Platz für Favoriten-Button
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
                            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
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
                            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                    ],
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
                    if (widget.movie.year != null)
                      Text(
                        widget.movie.year!,
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
                      ),
                  ],
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
class _SearchSeriesCard extends StatefulWidget {
  final XTremeCodeSeriesItem series;
  final VoidCallback onTap;

  const _SearchSeriesCard({required this.series, required this.onTap});

  @override
  State<_SearchSeriesCard> createState() => _SearchSeriesCardState();
}

class _SearchSeriesCardState extends State<_SearchSeriesCard>
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(context, alignment: 0.5,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      });
    } else {
      _scaleController.reverse();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final metadata = ContentParser.parse(widget.series.name ?? '');
    final favoriteId = 'series_${widget.series.seriesId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    return Focus(
      focusNode: _focusNode,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(scale: _scaleAnimation.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused ? Colors.white : colorScheme.outline.withAlpha(25),
                width: _isFocused ? 3 : 1,
              ),
              boxShadow: _isFocused
                  ? [BoxShadow(color: Colors.white.withAlpha(50), blurRadius: 16, spreadRadius: 2)]
                  : null,
            ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.series.cover != null
                    ? CachedNetworkImage(
                        imageUrl: widget.series.cover!,
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
                      seriesId: widget.series.seriesId ?? 0,
                      title: widget.series.name ?? '',
                      imageUrl: widget.series.cover,
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
              // Quality + Language badges
              if (metadata.quality != null || metadata.language != null)
                Positioned(
                  top: 6,
                  left: 6,
                  right: 40, // Platz für Favoriten-Button
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
                            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
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
                            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                    ],
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
                    if (widget.series.year != null)
                      Text(
                        widget.series.year!,
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
                      ),
                  ],
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
class _SearchLiveCard extends StatefulWidget {
  final XTremeCodeLiveStreamItem stream;
  final VoidCallback onTap;

  const _SearchLiveCard({required this.stream, required this.onTap});

  @override
  State<_SearchLiveCard> createState() => _SearchLiveCardState();
}

class _SearchLiveCardState extends State<_SearchLiveCard>
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(context, alignment: 0.5,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      });
    } else {
      _scaleController.reverse();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final metadata = ContentParser.parse(widget.stream.name ?? '');
    final favoriteId = 'live_${widget.stream.streamId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    return Focus(
      focusNode: _focusNode,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(scale: _scaleAnimation.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused ? Colors.white : colorScheme.outline.withAlpha(25),
                width: _isFocused ? 3 : 1,
              ),
              boxShadow: _isFocused
                  ? [BoxShadow(color: Colors.white.withAlpha(50), blurRadius: 16, spreadRadius: 2)]
                  : null,
            ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.stream.streamIcon != null
                    ? CachedNetworkImage(
                        imageUrl: widget.stream.streamIcon!,
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
                      streamId: widget.stream.streamId ?? 0,
                      title: widget.stream.name ?? '',
                      imageUrl: widget.stream.streamIcon,
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
