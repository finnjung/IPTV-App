import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/start_screen.dart';
import '../../screens/live_tv_screen.dart';
import '../../screens/movies_screen.dart';
import '../../screens/series_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/search_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _slideLineController;

  static const List<String> _tabLabels = [
    'Start',
    'Filme',
    'Serien',
    'Live',
    'Profil',
  ];

  static const List<String> _tabIcons = [
    'assets/icons/house-simple.svg',
    'assets/icons/film-strip.svg',
    'assets/icons/monitor-play.svg',
    'assets/icons/broadcast.svg',
    'assets/icons/user.svg',
  ];

  static const List<Widget> _screens = [
    StartScreen(),
    MoviesScreen(),
    SeriesScreen(),
    LiveTvScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _slideLineController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideLineController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideLineController.dispose();
    super.dispose();
  }

  bool _isDesktopPlatform() {
    if (kIsWeb) return true;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  bool _isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768;
  }

  bool _useDesktopLayout(BuildContext context) {
    return _isDesktopPlatform() && _isWideScreen(context);
  }

  void _onPageChanged(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.lightImpact();
      setState(() => _selectedIndex = index);
      _slideLineController.forward(from: 0);
    }
  }

  void _onItemTapped(int index) async {
    if (_selectedIndex != index) {
      HapticFeedback.lightImpact();
      setState(() => _selectedIndex = index);

      final distance = (index - _selectedIndex.abs()).abs();
      final duration = Duration(milliseconds: 250 + (distance * 50));

      await _pageController.animateToPage(
        index,
        duration: duration,
        curve: Curves.easeOutCubic,
      );

      _slideLineController.forward(from: 0);
    }
  }

  void _openSearch() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  Widget _buildTabIcon(int index, bool isActive) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isActive
        ? colorScheme.onSurface
        : colorScheme.onSurface.withAlpha(100);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(0, isActive ? -2 : 0, 0),
      child: SvgPicture.asset(
        _tabIcons[index],
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      ),
    );
  }

  // Desktop/Web Navigation Overlay (transparent, über dem Content)
  // Zeigt: "Willkommen zurück" links (nur Start-Tab) | Nav-Tabs + Suche + Profil rechts
  Widget _buildDesktopNavOverlay() {
    // Extra Padding für macOS wegen Titelleiste mit Traffic Lights
    final extraTopPadding = !kIsWeb && Platform.isMacOS ? 28.0 : 0.0;
    final isStartScreen = _selectedIndex == 0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(32, 20 + extraTopPadding, 32, 20),
          child: Row(
            children: [
              // "Willkommen zurück" + Untertitel links (nur auf Start-Screen)
              if (isStartScreen)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Willkommen',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black.withAlpha(150),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'zurück',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withAlpha(180),
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black.withAlpha(150),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Was möchtest du schauen?',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withAlpha(160),
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black.withAlpha(120),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              const Spacer(),

              // Navigation Tabs
              Row(
                children: List.generate(4, (index) {
                  final isSelected = _selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: GestureDetector(
                      onTap: () => _onItemTapped(index),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withAlpha(20)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _tabLabels[index],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withAlpha(200),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            shadows: [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black.withAlpha(120),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(width: 20),

              // Such-Icon
              GestureDetector(
                onTap: _openSearch,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withAlpha(30),
                      width: 1,
                    ),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/magnifying-glass.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Profil Icon
              GestureDetector(
                onTap: () => _onItemTapped(4),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 4
                        ? Colors.white.withAlpha(30)
                        : Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withAlpha(30),
                      width: 1,
                    ),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/user.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mobile Navigation (unten)
  Widget _buildMobileBottomNavigation() {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withAlpha(245),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 25,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Stack(
            children: [
              // Slide Line oben
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Stack(
                  children: [
                    Container(
                      height: 2,
                      color: colorScheme.outline.withAlpha(25),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: _selectedIndex * (screenWidth / 5),
                      child: Container(
                        height: 2,
                        width: screenWidth / 5,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.onSurface.withAlpha(50),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Navigation Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_tabLabels.length, (index) {
                  final isSelected = _selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onItemTapped(index),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: 70,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTabIcon(index, isSelected),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: isSelected ? 18 : 0,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isSelected ? 1.0 : 0.0,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _tabLabels[index],
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _useDesktopLayout(context);
    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Content (PageView)
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: isDesktop ? const NeverScrollableScrollPhysics() : null,
            children: _screens,
          ),
          // Desktop Navigation Overlay (über dem Content)
          if (isDesktop) _buildDesktopNavOverlay(),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildMobileBottomNavigation(),
    );
  }
}
