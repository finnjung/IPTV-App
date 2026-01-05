import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../widgets/content_card.dart';
import '../utils/content_parser.dart';
import 'player_screen.dart';
import 'search_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  List<XTremeCodeLiveStreamItem> _streams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStreams();
  }

  Future<void> _loadStreams() async {
    final xtreamService = context.read<XtreamService>();

    if (!xtreamService.isConnected) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    final streams = await xtreamService.getLiveStreams();

    if (mounted) {
      setState(() {
        _streams = streams;
        _isLoading = false;
      });
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
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();

    return Scaffold(
      body: SafeArea(
        child: !xtreamService.isConnected
            ? _buildNotConnected(context)
            : CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/icons/broadcast.svg',
                                width: 28,
                                height: 28,
                                colorFilter: ColorFilter.mode(
                                  colorScheme.onSurface,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Live TV',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SearchScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/icons/magnifying-glass.svg',
                                    width: 22,
                                    height: 22,
                                    colorFilter: ColorFilter.mode(
                                      colorScheme.onSurface.withAlpha(180),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isLoading
                                ? 'Lädt...'
                                : '${_streams.length} Sender verfügbar',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Loading or Content
                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  else if (_streams.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
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
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final stream = _streams[index];
                            return ContentCard(
                              title: stream.name ?? 'Unbekannt',
                              subtitle: null,
                              imageUrl: stream.streamIcon,
                              icon: 'assets/icons/television.svg',
                              isLive: true,
                              onTap: () => _playStream(stream),
                            );
                          },
                          childCount: _streams.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
