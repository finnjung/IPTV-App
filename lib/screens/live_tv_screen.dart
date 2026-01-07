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
import '../models/favorite.dart';
import '../models/watch_progress.dart';
import '../utils/content_parser.dart';
import 'player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  bool _showAllStreams = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final xtreamService = context.read<XtreamService>();
    if (xtreamService.isConnected) {
      await xtreamService.loadLiveTvScreenContent();
    }
  }

  void _playStream(XTremeCodeLiveStreamItem stream) {
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
    final xtreamService = context.watch<XtreamService>();
    final content = xtreamService.liveTvScreenContent;
    // Auch Preloading berücksichtigen
    final isLoading = xtreamService.isLoadingLiveTv || xtreamService.isPreloading;

    return Scaffold(
      body: !xtreamService.isConnected
          ? SafeArea(child: _buildNotConnected(context))
          : CustomScrollView(
              slivers: [
                // Sticky Glass Header
                StickyGlassHeader(
                  title: 'Live TV',
                  subtitle: isLoading
                      ? 'Laden...'
                      : '${content?.allStreamsSorted.length ?? 0} Sender verfugbar',
                  iconPath: 'assets/icons/broadcast.svg',
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
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: category.items.length,
                          itemBuilder: (context, index) {
                            final stream = category.items[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < category.items.length - 1 ? 12 : 0,
                              ),
                              child: _LiveTvCard(
                                stream: stream,
                                onTap: () => _playStream(stream),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // All Streams Section Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                      child: SectionHeader(
                        title: 'Alle Sender (A-Z)',
                        icon: 'assets/icons/list.svg',
                        onSeeAll: _showAllStreams
                            ? null
                            : () => setState(() => _showAllStreams = true),
                      ),
                    ),
                  ),

                  // All Streams Grid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: ResponsiveSliverGrid(
                      itemCount: _showAllStreams
                          ? content.allStreamsSorted.length
                          : content.allStreamsSorted.length.clamp(0, 20),
                      childAspectRatio: 1.3,
                      itemBuilder: (context, index) {
                        final stream = content.allStreamsSorted[index];
                        return ContentCard(
                          title: stream.name ?? 'Unbekannt',
                          subtitle: null,
                          imageUrl: stream.streamIcon,
                          icon: 'assets/icons/television.svg',
                          isLive: true,
                          onTap: () => _playStream(stream),
                        );
                      },
                    ),
                  ),

                  // Show more button
                  if (!_showAllStreams && content.allStreamsSorted.length > 20)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _showAllStreams = true),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: colorScheme.outline.withAlpha(50),
                            ),
                          ),
                          child: Text(
                            'Alle ${content.allStreamsSorted.length} Sender anzeigen',
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
              'assets/icons/television.svg',
              width: 48,
              height: 48,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface.withAlpha(100),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Sender gefunden',
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

class _LiveTvCard extends StatelessWidget {
  final XTremeCodeLiveStreamItem stream;
  final VoidCallback onTap;

  const _LiveTvCard({
    required this.stream,
    required this.onTap,
  });

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
        width: 160,
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
                  child: stream.streamIcon != null
                      ? CachedNetworkImage(
                          imageUrl: stream.streamIcon!,
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
                      stops: const [0.0, 0.35, 0.55, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
              // Live Badge
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Favorite button (top right)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    final favorite = Favorite.fromLiveStream(
                      streamId: stream.streamId ?? 0,
                      title: stream.name ?? '',
                      imageUrl: stream.streamIcon,
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
              // Title at bottom
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        metadata.cleanName,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (metadata.country != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          metadata.country!,
                          style: GoogleFonts.poppins(
                            fontSize: 8,
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
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: SvgPicture.asset(
        'assets/icons/television.svg',
        width: 28,
        height: 28,
        colorFilter: ColorFilter.mode(
          colorScheme.onSurface.withAlpha(30),
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
