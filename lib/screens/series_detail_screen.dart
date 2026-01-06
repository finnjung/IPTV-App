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
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final XTremeCodeSeriesItem series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  XTremeCodeSeriesInfo? _seriesInfo;
  bool _isLoading = true;
  int _selectedSeason = 0;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  Future<void> _loadSeriesInfo() async {
    final xtreamService = context.read<XtreamService>();
    final info = await xtreamService.getSeriesInfo(widget.series);

    if (mounted) {
      // Prüfen ob die Serie leer ist (keine Episoden/Staffeln)
      final isEmpty = info == null ||
          info.episodes == null ||
          info.episodes!.isEmpty ||
          info.seasons == null ||
          info.seasons!.isEmpty;

      if (isEmpty && widget.series.seriesId != null) {
        // Serie als leer markieren für zukünftiges Ausblenden
        await xtreamService.markSeriesAsEmpty(widget.series.seriesId!);
      }

      setState(() {
        _seriesInfo = info;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _playEpisode(XTremeCodeEpisode episode, int seasonNum) {
    final xtreamService = context.read<XtreamService>();
    final url = xtreamService.getSeriesEpisodeUrl(
      episode.id ?? 0,
      container: episode.containerExtension ?? 'mp4',
    );

    if (url != null) {
      final metadata = ContentParser.parse(widget.series.name ?? 'Serie');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: metadata.cleanName,
            subtitle: 'S$seasonNum E${episode.episodeNum ?? 1}: ${episode.title ?? "Episode"}',
            streamUrl: url,
            contentId: 'series_${widget.series.seriesId}_${seasonNum}_${episode.episodeNum ?? 1}',
            imageUrl: episode.info.movieImage ?? widget.series.cover,
            contentType: ContentType.series,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final favoriteId = 'series_${widget.series.seriesId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Header with cover image
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: colorScheme.surface,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/caret-left.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        final favorite = Favorite.fromSeries(
                          seriesId: widget.series.seriesId ?? 0,
                          title: widget.series.name ?? '',
                          imageUrl: widget.series.cover,
                        );
                        xtreamService.toggleFavorite(favorite);
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(100),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          isFavorite ? 'assets/icons/heart-fill.svg' : 'assets/icons/heart.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.series.cover != null)
                          CachedNetworkImage(
                            imageUrl: widget.series.cover!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: colorScheme.surface,
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                colorScheme.surface,
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Series Info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ContentParser.parse(widget.series.name ?? 'Unbekannt').cleanName,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_seriesInfo?.info.releaseDate != null) ...[
                              Text(
                                _formatDate(_seriesInfo!.info.releaseDate!),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withAlpha(150),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (_seriesInfo?.seasons != null)
                              Text(
                                '${_seriesInfo!.seasons!.length} Staffeln',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withAlpha(150),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        if (_seriesInfo?.info.plot != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _seriesInfo!.info.plot!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha(180),
                              height: 1.5,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Season Tabs
                if (_seriesInfo?.seasons != null &&
                    _seriesInfo!.seasons!.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _seriesInfo!.seasons!.length,
                        itemBuilder: (context, index) {
                          final season = _seriesInfo!.seasons![index];
                          final isSelected = _selectedSeason == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedSeason = index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.onSurface
                                      : colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.onSurface
                                        : colorScheme.outline.withAlpha(50),
                                  ),
                                ),
                                child: Text(
                                  season.name ?? 'Staffel ${index + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colorScheme.surface
                                        : colorScheme.onSurface.withAlpha(180),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // Episodes
                if (_seriesInfo?.episodes != null &&
                    _seriesInfo?.seasons != null &&
                    _seriesInfo!.seasons!.isNotEmpty)
                  _buildEpisodesList(colorScheme)
                else if (!_isLoading)
                  SliverToBoxAdapter(
                    child: Center(
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
                              'Keine Episoden verfügbar',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildEpisodesList(ColorScheme colorScheme) {
    // Sicherheitsprüfung
    if (_seriesInfo?.seasons == null ||
        _seriesInfo!.seasons!.isEmpty ||
        _selectedSeason >= _seriesInfo!.seasons!.length) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'Keine Staffeln verfügbar',
              style: GoogleFonts.poppins(
                color: colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
        ),
      );
    }

    final seasonNumber = _seriesInfo!.seasons![_selectedSeason].seasonNumber;
    final episodes = _seriesInfo!.episodes?[seasonNumber.toString()] ?? [];

    if (episodes.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'Keine Episoden gefunden',
              style: GoogleFonts.poppins(
                color: colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final episode = episodes[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outline.withAlpha(25),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _playEpisode(episode, seasonNumber ?? 1),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Episode Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 120,
                            height: 70,
                            color: colorScheme.surface,
                            child: episode.info.movieImage != null
                                ? CachedNetworkImage(
                                    imageUrl: episode.info.movieImage!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _buildEpisodePlaceholder(colorScheme),
                                  )
                                : _buildEpisodePlaceholder(colorScheme),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Episode Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Episode ${episode.episodeNum ?? (index + 1)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withAlpha(150),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                episode.title ?? 'Unbekannt',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (episode.info.duration != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  episode.info.duration!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color:
                                        colorScheme.onSurface.withAlpha(150),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Play Button
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withAlpha(15),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/play.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: episodes.length,
        ),
      ),
    );
  }

  Widget _buildEpisodePlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/monitor-play.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            colorScheme.onSurface.withAlpha(75),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget to navigate to SeriesDetailScreen from favorites
/// without needing a full XTremeCodeSeriesItem
class SeriesDetailScreenFromFavorite extends StatefulWidget {
  final int seriesId;
  final String seriesName;
  final String? seriesCover;

  const SeriesDetailScreenFromFavorite({
    super.key,
    required this.seriesId,
    required this.seriesName,
    this.seriesCover,
  });

  @override
  State<SeriesDetailScreenFromFavorite> createState() =>
      _SeriesDetailScreenFromFavoriteState();
}

class _SeriesDetailScreenFromFavoriteState
    extends State<SeriesDetailScreenFromFavorite> {
  XTremeCodeSeriesInfo? _seriesInfo;
  bool _isLoading = true;
  int _selectedSeason = 0;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  Future<void> _loadSeriesInfo() async {
    final xtreamService = context.read<XtreamService>();

    try {
      // Get series info using the service method
      final info = await xtreamService.getSeriesInfoById(widget.seriesId);

      if (mounted) {
        setState(() {
          _seriesInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _playEpisode(XTremeCodeEpisode episode, int seasonNum) {
    final xtreamService = context.read<XtreamService>();
    final url = xtreamService.getSeriesEpisodeUrl(
      episode.id ?? 0,
      container: episode.containerExtension ?? 'mp4',
    );

    if (url != null) {
      final metadata = ContentParser.parse(widget.seriesName);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: metadata.cleanName,
            subtitle:
                'S$seasonNum E${episode.episodeNum ?? 1}: ${episode.title ?? "Episode"}',
            streamUrl: url,
            contentId:
                'series_${widget.seriesId}_${seasonNum}_${episode.episodeNum ?? 1}',
            imageUrl: episode.info.movieImage ?? widget.seriesCover,
            contentType: ContentType.series,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final favoriteId = 'series_${widget.seriesId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Header with cover image
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: colorScheme.surface,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/caret-left.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        final favorite = Favorite.fromSeries(
                          seriesId: widget.seriesId,
                          title: widget.seriesName,
                          imageUrl: widget.seriesCover,
                        );
                        xtreamService.toggleFavorite(favorite);
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFavorite
                              ? Colors.red.withAlpha(200)
                              : Colors.black.withAlpha(100),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/heart.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.seriesCover != null)
                          CachedNetworkImage(
                            imageUrl: widget.seriesCover!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: colorScheme.surface,
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                colorScheme.surface,
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Series Info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ContentParser.parse(widget.seriesName).cleanName,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_seriesInfo?.info.releaseDate != null) ...[
                              Text(
                                _formatDate(_seriesInfo!.info.releaseDate!),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withAlpha(150),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (_seriesInfo?.seasons != null)
                              Text(
                                '${_seriesInfo!.seasons!.length} Staffeln',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withAlpha(150),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        if (_seriesInfo?.info.plot != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _seriesInfo!.info.plot!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha(180),
                              height: 1.5,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Season Tabs
                if (_seriesInfo?.seasons != null &&
                    _seriesInfo!.seasons!.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _seriesInfo!.seasons!.length,
                        itemBuilder: (context, index) {
                          final season = _seriesInfo!.seasons![index];
                          final isSelected = _selectedSeason == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedSeason = index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.onSurface
                                      : colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.onSurface
                                        : colorScheme.outline.withAlpha(50),
                                  ),
                                ),
                                child: Text(
                                  season.name ?? 'Staffel ${index + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colorScheme.surface
                                        : colorScheme.onSurface.withAlpha(180),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // Episodes
                if (_seriesInfo?.episodes != null &&
                    _seriesInfo?.seasons != null &&
                    _seriesInfo!.seasons!.isNotEmpty)
                  _buildEpisodesList(colorScheme)
                else if (!_isLoading)
                  SliverToBoxAdapter(
                    child: Center(
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
                              'Keine Episoden verfügbar',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildEpisodesList(ColorScheme colorScheme) {
    if (_seriesInfo?.seasons == null ||
        _seriesInfo!.seasons!.isEmpty ||
        _selectedSeason >= _seriesInfo!.seasons!.length) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'Keine Staffeln verfügbar',
              style: GoogleFonts.poppins(
                color: colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
        ),
      );
    }

    final seasonNumber = _seriesInfo!.seasons![_selectedSeason].seasonNumber;
    final episodes = _seriesInfo!.episodes?[seasonNumber.toString()] ?? [];

    if (episodes.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'Keine Episoden gefunden',
              style: GoogleFonts.poppins(
                color: colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final episode = episodes[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outline.withAlpha(25),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _playEpisode(episode, seasonNumber ?? 1),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 120,
                            height: 70,
                            color: colorScheme.surface,
                            child: episode.info.movieImage != null
                                ? CachedNetworkImage(
                                    imageUrl: episode.info.movieImage!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _buildEpisodePlaceholder(colorScheme),
                                  )
                                : _buildEpisodePlaceholder(colorScheme),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Episode ${episode.episodeNum ?? (index + 1)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withAlpha(150),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                episode.title ?? 'Unbekannt',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (episode.info.duration != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  episode.info.duration!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withAlpha(150),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withAlpha(15),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/play.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: episodes.length,
        ),
      ),
    );
  }

  Widget _buildEpisodePlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/monitor-play.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            colorScheme.onSurface.withAlpha(75),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
