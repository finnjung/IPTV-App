import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
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
      setState(() {
        _seriesInfo = info;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _playEpisode(XTremeCodeEpisode episode) {
    final xtreamService = context.read<XtreamService>();
    final url = xtreamService.getSeriesEpisodeUrl(
      episode.id ?? 0,
      container: episode.containerExtension ?? 'mp4',
    );

    if (url != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: widget.series.name ?? 'Serie',
            subtitle: episode.title ?? 'Episode',
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
                          widget.series.name ?? 'Unbekannt',
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
                                  color: colorScheme.primary,
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
                                      ? colorScheme.primary
                                      : colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
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
                                        ? Colors.white
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
                if (_seriesInfo?.episodes != null)
                  _buildEpisodesList(colorScheme),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildEpisodesList(ColorScheme colorScheme) {
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
                  onTap: () => _playEpisode(episode),
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
                                  color: colorScheme.primary,
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
                            color: colorScheme.primary.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/play.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              colorScheme.primary,
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
