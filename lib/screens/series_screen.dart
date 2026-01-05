import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../widgets/content_card.dart';
import 'series_detail_screen.dart';
import 'search_screen.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<XTremeCodeSeriesItem> _series = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final xtreamService = context.read<XtreamService>();

    if (!xtreamService.isConnected) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    final series = await xtreamService.getSeries();

    if (mounted) {
      setState(() {
        _series = series;
        _isLoading = false;
      });
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
                                'assets/icons/monitor-play.svg',
                                width: 28,
                                height: 28,
                                colorFilter: ColorFilter.mode(
                                  colorScheme.onSurface,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Serien',
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
                                : '${_series.length} Serien verfügbar',
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
                  else if (_series.isEmpty)
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
                                'Keine Serien gefunden',
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
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final series = _series[index];
                            return ContentCard(
                              title: series.name ?? 'Unbekannt',
                              subtitle: series.year,
                              imageUrl: series.cover,
                              icon: 'assets/icons/monitor-play.svg',
                              onTap: () => _openSeries(series),
                            );
                          },
                          childCount: _series.length,
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
