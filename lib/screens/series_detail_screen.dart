import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xtream_code_client/xtream_code_client.dart' hide Image;
import '../services/xtream_service.dart';
import '../models/watch_progress.dart';
import '../models/favorite.dart';
import '../utils/content_parser.dart';
import 'player_screen.dart';

// Hilfsfunktion für Episode Content ID
String _getEpisodeContentId(int seriesId, int seasonNum, int episodeNum) {
  return 'series_${seriesId}_${seasonNum}_$episodeNum';
}

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

  void _playEpisode(XTremeCodeEpisode episode, int seasonNum, {bool resume = true}) {
    final xtreamService = context.read<XtreamService>();
    final contentId = _getEpisodeContentId(
      widget.series.seriesId ?? 0,
      seasonNum,
      episode.episodeNum ?? 1,
    );

    final url = xtreamService.getSeriesEpisodeUrl(
      episode.id ?? 0,
      container: episode.containerExtension ?? 'mp4',
    );

    if (url != null) {
      // Wenn nicht fortsetzen, Progress löschen
      if (!resume) {
        xtreamService.removeWatchProgress(contentId);
      }

      final metadata = ContentParser.parse(widget.series.name ?? 'Serie');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: metadata.cleanName,
            subtitle: 'S$seasonNum E${episode.episodeNum ?? 1}: ${episode.title ?? "Episode"}',
            streamUrl: url,
            contentId: contentId,
            imageUrl: episode.info.movieImage ?? widget.series.cover,
            contentType: ContentType.series,
          ),
        ),
      );
    }
  }

  /// Findet die letzte angeschaute Episode dieser Serie
  (XTremeCodeEpisode?, int?, WatchProgress?)? _findLastWatchedEpisode(XtreamService xtreamService) {
    if (_seriesInfo?.episodes == null || _seriesInfo?.seasons == null) {
      return null;
    }

    WatchProgress? latestProgress;
    XTremeCodeEpisode? latestEpisode;
    int? latestSeasonNum;

    for (final season in _seriesInfo!.seasons!) {
      final seasonNum = season.seasonNumber ?? 1;
      final episodes = _seriesInfo!.episodes?[seasonNum.toString()] ?? [];

      for (final episode in episodes) {
        final contentId = _getEpisodeContentId(
          widget.series.seriesId ?? 0,
          seasonNum,
          episode.episodeNum ?? 1,
        );
        final progress = xtreamService.getWatchProgress(contentId);

        if (progress != null && progress.position.inSeconds > 30) {
          if (latestProgress == null || progress.lastWatched.isAfter(latestProgress.lastWatched)) {
            latestProgress = progress;
            latestEpisode = episode;
            latestSeasonNum = seasonNum;
          }
        }
      }
    }

    if (latestEpisode != null && latestSeasonNum != null && latestProgress != null) {
      return (latestEpisode, latestSeasonNum, latestProgress);
    }
    return null;
  }

  Widget _buildContinueWatchingSection(ColorScheme colorScheme, XtreamService xtreamService) {
    final lastWatched = _findLastWatchedEpisode(xtreamService);
    if (lastWatched == null) return const SizedBox.shrink();

    final (episode, seasonNum, progress) = lastWatched;
    if (episode == null || seasonNum == null || progress == null) return const SizedBox.shrink();

    // Progress berechnen
    final progressPercent = progress.duration.inSeconds > 0
        ? (progress.position.inSeconds / progress.duration.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    final remainingMinutes = ((progress.duration.inSeconds - progress.position.inSeconds) / 60).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary.withAlpha(50),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/clock.svg',
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Weiterschauen',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // Episode Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Thumbnail mit Play Overlay
                  GestureDetector(
                    onTap: () => _playEpisode(episode, seasonNum, resume: true),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(
                            width: 140,
                            height: 80,
                            color: colorScheme.onSurface.withAlpha(10),
                            child: episode.info.movieImage != null
                                ? CachedNetworkImage(
                                    imageUrl: episode.info.movieImage!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => _buildEpisodePlaceholder(colorScheme),
                                  )
                                : _buildEpisodePlaceholder(colorScheme),
                          ),
                          // Play Overlay
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withAlpha(80),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/icons/play.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Progress Bar
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(50),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progressPercent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'S$seasonNum E${episode.episodeNum ?? 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          episode.title ?? 'Episode ${episode.episodeNum ?? 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          remainingMinutes > 0
                              ? 'Noch $remainingMinutes Min.'
                              : 'Fast fertig',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  // Continue Button
                  Expanded(
                    child: ElevatedButton.icon(
                      autofocus: true, // Auto-focus for TV remote navigation
                      onPressed: () => _playEpisode(episode, seasonNum, resume: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: SvgPicture.asset(
                        'assets/icons/play.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      label: Text(
                        'Fortsetzen',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Restart Button
                  OutlinedButton(
                    onPressed: () => _playEpisode(episode, seasonNum, resume: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      side: BorderSide(
                        color: colorScheme.outline.withAlpha(80),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/arrow-counter-clockwise.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withAlpha(180),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final favoriteId = 'series_${widget.series.seriesId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    // Extra top padding für macOS Titelleiste
    final isMacOS = !kIsWeb && Platform.isMacOS;
    final macOSTopPadding = isMacOS ? 28.0 : 0.0;

    // Gleiche Hintergrundfarbe wie im HeroBanner/StartScreen
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : colorScheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Header with cover image und Titel auf dem Gradient
                SliverAppBar(
                  expandedHeight: 380 + macOSTopPadding,
                  pinned: true,
                  backgroundColor: bgColor,
                  toolbarHeight: kToolbarHeight + macOSTopPadding,
                  leading: Padding(
                    padding: EdgeInsets.only(top: macOSTopPadding),
                    child: IconButton(
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
                  ),
                  actions: [
                    Padding(
                      padding: EdgeInsets.only(top: macOSTopPadding),
                      child: IconButton(
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
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Cover-Bild
                        if (widget.series.cover != null)
                          CachedNetworkImage(
                            imageUrl: widget.series.cover!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: bgColor,
                            ),
                          ),
                        // Gradient mit 100% Deckung am Ende
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                bgColor.withAlpha(20),
                                bgColor.withAlpha(80),
                                bgColor.withAlpha(160),
                                bgColor.withAlpha(220),
                                bgColor,
                                bgColor,
                              ],
                              stops: const [0.0, 0.2, 0.35, 0.45, 0.55, 0.65, 0.78, 1.0],
                            ),
                          ),
                        ),
                        // Seitlicher Gradient für Tiefe
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withAlpha(60),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withAlpha(30),
                              ],
                              stops: const [0.0, 0.25, 0.75, 1.0],
                            ),
                          ),
                        ),
                        // Titel und Infos auf dem Gradient
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Streameee Branding
                              Opacity(
                                opacity: 0.7,
                                child: Text(
                                  'streameee',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Titel
                              Text(
                                ContentParser.parse(widget.series.name ?? 'Unbekannt').cleanName,
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              // Meta-Infos
                              Row(
                                children: [
                                  if (_seriesInfo?.info.releaseDate != null) ...[
                                    Text(
                                      _formatDate(_seriesInfo!.info.releaseDate!),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: colorScheme.onSurface.withAlpha(180),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 10),
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: colorScheme.onSurface.withAlpha(100),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                  if (_seriesInfo?.seasons != null)
                                    Text(
                                      '${_seriesInfo!.seasons!.length} Staffeln',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: colorScheme.onSurface.withAlpha(180),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              // Plot/Beschreibung
                              if (_seriesInfo?.info.plot != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _seriesInfo!.info.plot!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: colorScheme.onSurface.withAlpha(160),
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),

                      ],
                    ),
                  ),
                ),

                // Continue Watching Section (wenn vorhanden)
                if (!_isLoading && _seriesInfo != null)
                  SliverToBoxAdapter(
                    child: _buildContinueWatchingSection(colorScheme, xtreamService),
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

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

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
    final xtreamService = context.watch<XtreamService>();

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
            final contentId = _getEpisodeContentId(
              widget.series.seriesId ?? 0,
              seasonNumber ?? 1,
              episode.episodeNum ?? 1,
            );
            final progress = xtreamService.getWatchProgress(contentId);
            final hasProgress = progress != null && progress.position.inSeconds > 30;
            final progressPercent = hasProgress && progress.duration.inSeconds > 0
                ? (progress.position.inSeconds / progress.duration.inSeconds).clamp(0.0, 1.0)
                : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasProgress
                      ? colorScheme.primary.withAlpha(60)
                      : colorScheme.outline.withAlpha(25),
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
                        // Episode Thumbnail with progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Container(
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
                              // Progress bar overlay
                              if (hasProgress)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 3,
                                    color: Colors.black.withAlpha(100),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progressPercent,
                                      child: Container(
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Episode Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Episode ${episode.episodeNum ?? (index + 1)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: hasProgress
                                          ? colorScheme.primary
                                          : colorScheme.onSurface.withAlpha(150),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (hasProgress) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${(progressPercent * 100).round()}%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
                        // Play/Resume Button
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: hasProgress
                                ? colorScheme.primary.withAlpha(30)
                                : colorScheme.onSurface.withAlpha(15),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/play.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              hasProgress ? colorScheme.primary : colorScheme.onSurface,
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

  void _playEpisode(XTremeCodeEpisode episode, int seasonNum, {bool resume = true}) {
    final xtreamService = context.read<XtreamService>();
    final contentId = _getEpisodeContentId(
      widget.seriesId,
      seasonNum,
      episode.episodeNum ?? 1,
    );

    final url = xtreamService.getSeriesEpisodeUrl(
      episode.id ?? 0,
      container: episode.containerExtension ?? 'mp4',
    );

    if (url != null) {
      // Wenn nicht fortsetzen, Progress löschen
      if (!resume) {
        xtreamService.removeWatchProgress(contentId);
      }

      final metadata = ContentParser.parse(widget.seriesName);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: metadata.cleanName,
            subtitle: 'S$seasonNum E${episode.episodeNum ?? 1}: ${episode.title ?? "Episode"}',
            streamUrl: url,
            contentId: contentId,
            imageUrl: episode.info.movieImage ?? widget.seriesCover,
            contentType: ContentType.series,
          ),
        ),
      );
    }
  }

  /// Findet die letzte angeschaute Episode dieser Serie
  (XTremeCodeEpisode?, int?, WatchProgress?)? _findLastWatchedEpisode(XtreamService xtreamService) {
    if (_seriesInfo?.episodes == null || _seriesInfo?.seasons == null) {
      return null;
    }

    WatchProgress? latestProgress;
    XTremeCodeEpisode? latestEpisode;
    int? latestSeasonNum;

    for (final season in _seriesInfo!.seasons!) {
      final seasonNum = season.seasonNumber ?? 1;
      final episodes = _seriesInfo!.episodes?[seasonNum.toString()] ?? [];

      for (final episode in episodes) {
        final contentId = _getEpisodeContentId(
          widget.seriesId,
          seasonNum,
          episode.episodeNum ?? 1,
        );
        final progress = xtreamService.getWatchProgress(contentId);

        if (progress != null && progress.position.inSeconds > 30) {
          if (latestProgress == null || progress.lastWatched.isAfter(latestProgress.lastWatched)) {
            latestProgress = progress;
            latestEpisode = episode;
            latestSeasonNum = seasonNum;
          }
        }
      }
    }

    if (latestEpisode != null && latestSeasonNum != null && latestProgress != null) {
      return (latestEpisode, latestSeasonNum, latestProgress);
    }
    return null;
  }

  Widget _buildContinueWatchingSection(ColorScheme colorScheme, XtreamService xtreamService) {
    final lastWatched = _findLastWatchedEpisode(xtreamService);
    if (lastWatched == null) return const SizedBox.shrink();

    final (episode, seasonNum, progress) = lastWatched;
    if (episode == null || seasonNum == null || progress == null) return const SizedBox.shrink();

    // Progress berechnen
    final progressPercent = progress.duration.inSeconds > 0
        ? (progress.position.inSeconds / progress.duration.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    final remainingMinutes = ((progress.duration.inSeconds - progress.position.inSeconds) / 60).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary.withAlpha(50),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/clock.svg',
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Weiterschauen',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // Episode Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Thumbnail mit Play Overlay
                  GestureDetector(
                    onTap: () => _playEpisode(episode, seasonNum, resume: true),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(
                            width: 140,
                            height: 80,
                            color: colorScheme.onSurface.withAlpha(10),
                            child: episode.info.movieImage != null
                                ? CachedNetworkImage(
                                    imageUrl: episode.info.movieImage!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => _buildEpisodePlaceholder(colorScheme),
                                  )
                                : _buildEpisodePlaceholder(colorScheme),
                          ),
                          // Play Overlay
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withAlpha(80),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/icons/play.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Progress Bar
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(50),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progressPercent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'S$seasonNum E${episode.episodeNum ?? 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          episode.title ?? 'Episode ${episode.episodeNum ?? 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          remainingMinutes > 0
                              ? 'Noch $remainingMinutes Min.'
                              : 'Fast fertig',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  // Continue Button
                  Expanded(
                    child: ElevatedButton.icon(
                      autofocus: true, // Auto-focus for TV remote navigation
                      onPressed: () => _playEpisode(episode, seasonNum, resume: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: SvgPicture.asset(
                        'assets/icons/play.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      label: Text(
                        'Fortsetzen',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Restart Button
                  OutlinedButton(
                    onPressed: () => _playEpisode(episode, seasonNum, resume: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      side: BorderSide(
                        color: colorScheme.outline.withAlpha(80),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/arrow-counter-clockwise.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withAlpha(180),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final favoriteId = 'series_${widget.seriesId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);

    // Extra top padding für macOS Titelleiste
    final isMacOS = !kIsWeb && Platform.isMacOS;
    final macOSTopPadding = isMacOS ? 28.0 : 0.0;

    // Gleiche Hintergrundfarbe wie im HeroBanner/StartScreen
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : colorScheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Header with cover image und Titel auf dem Gradient
                SliverAppBar(
                  expandedHeight: 380 + macOSTopPadding,
                  pinned: true,
                  backgroundColor: bgColor,
                  toolbarHeight: kToolbarHeight + macOSTopPadding,
                  leading: Padding(
                    padding: EdgeInsets.only(top: macOSTopPadding),
                    child: IconButton(
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
                  ),
                  actions: [
                    Padding(
                      padding: EdgeInsets.only(top: macOSTopPadding),
                      child: IconButton(
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
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Cover-Bild
                        if (widget.seriesCover != null)
                          CachedNetworkImage(
                            imageUrl: widget.seriesCover!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: bgColor,
                            ),
                          ),
                        // Gradient mit 100% Deckung am Ende
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                bgColor.withAlpha(20),
                                bgColor.withAlpha(80),
                                bgColor.withAlpha(160),
                                bgColor.withAlpha(220),
                                bgColor,
                                bgColor,
                              ],
                              stops: const [0.0, 0.2, 0.35, 0.45, 0.55, 0.65, 0.78, 1.0],
                            ),
                          ),
                        ),
                        // Seitlicher Gradient für Tiefe
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withAlpha(60),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withAlpha(30),
                              ],
                              stops: const [0.0, 0.25, 0.75, 1.0],
                            ),
                          ),
                        ),
                        // Titel und Infos auf dem Gradient
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Streameee Branding
                              Opacity(
                                opacity: 0.7,
                                child: Text(
                                  'streameee',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Titel
                              Text(
                                ContentParser.parse(widget.seriesName).cleanName,
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              // Meta-Infos
                              Row(
                                children: [
                                  if (_seriesInfo?.info.releaseDate != null) ...[
                                    Text(
                                      _formatDate(_seriesInfo!.info.releaseDate!),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: colorScheme.onSurface.withAlpha(180),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 10),
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: colorScheme.onSurface.withAlpha(100),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                  if (_seriesInfo?.seasons != null)
                                    Text(
                                      '${_seriesInfo!.seasons!.length} Staffeln',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: colorScheme.onSurface.withAlpha(180),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              // Plot/Beschreibung
                              if (_seriesInfo?.info.plot != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _seriesInfo!.info.plot!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: colorScheme.onSurface.withAlpha(160),
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),

                      ],
                    ),
                  ),
                ),

                // Continue Watching Section (wenn vorhanden)
                if (!_isLoading && _seriesInfo != null)
                  SliverToBoxAdapter(
                    child: _buildContinueWatchingSection(colorScheme, xtreamService),
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

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

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
    final xtreamService = context.watch<XtreamService>();

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
            final contentId = _getEpisodeContentId(
              widget.seriesId,
              seasonNumber ?? 1,
              episode.episodeNum ?? 1,
            );
            final progress = xtreamService.getWatchProgress(contentId);
            final hasProgress = progress != null && progress.position.inSeconds > 30;
            final progressPercent = hasProgress && progress.duration.inSeconds > 0
                ? (progress.position.inSeconds / progress.duration.inSeconds).clamp(0.0, 1.0)
                : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasProgress
                      ? colorScheme.primary.withAlpha(60)
                      : colorScheme.outline.withAlpha(25),
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
                        // Episode Thumbnail with progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Container(
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
                              // Progress bar overlay
                              if (hasProgress)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 3,
                                    color: Colors.black.withAlpha(100),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progressPercent,
                                      child: Container(
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Episode Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Episode ${episode.episodeNum ?? (index + 1)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: hasProgress
                                          ? colorScheme.primary
                                          : colorScheme.onSurface.withAlpha(150),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (hasProgress) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${(progressPercent * 100).round()}%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
                        // Play/Resume Button
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: hasProgress
                                ? colorScheme.primary.withAlpha(30)
                                : colorScheme.onSurface.withAlpha(15),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/play.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              hasProgress ? colorScheme.primary : colorScheme.onSurface,
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
