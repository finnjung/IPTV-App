import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/search_screen.dart';

class StickyGlassHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconPath;

  const StickyGlassHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconPath,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyGlassHeaderDelegate(
        title: title,
        subtitle: subtitle,
        iconPath: iconPath,
      ),
    );
  }
}

class _StickyGlassHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String subtitle;
  final String iconPath;

  _StickyGlassHeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.iconPath,
  });

  @override
  double get minExtent => 130;

  @override
  double get maxExtent => 130;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            backgroundColor,
            backgroundColor,
            backgroundColor.withAlpha(242), // 95%
            backgroundColor.withAlpha(204), // 80%
            backgroundColor.withAlpha(128), // 50%
            backgroundColor.withAlpha(51),  // 20%
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 0.65, 0.75, 0.85, 0.93, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    iconPath,
                    width: 28,
                    height: 28,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/icons/magnifying-glass.svg',
                      width: 26,
                      height: 26,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withAlpha(180),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyGlassHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        subtitle != oldDelegate.subtitle ||
        iconPath != oldDelegate.iconPath;
  }
}

/// Header for the Start screen with "Willkommen zurück" style
class StickyStartHeader extends StatelessWidget {
  const StickyStartHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyStartHeaderDelegate(),
    );
  }
}

class _StickyStartHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 130;

  @override
  double get maxExtent => 130;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            backgroundColor,
            backgroundColor,
            backgroundColor.withAlpha(242), // 95%
            backgroundColor.withAlpha(204), // 80%
            backgroundColor.withAlpha(128), // 50%
            backgroundColor.withAlpha(51),  // 20%
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 0.65, 0.75, 0.85, 0.93, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    'Willkommen',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'zurück',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Was möchtest du schauen?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/icons/magnifying-glass.svg',
                      width: 26,
                      height: 26,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withAlpha(180),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyStartHeaderDelegate oldDelegate) {
    return false;
  }
}
