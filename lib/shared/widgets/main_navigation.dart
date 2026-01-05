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
    'Live',
    'Filme',
    'Serien',
    'Profil',
  ];

  static const List<String> _tabIcons = [
    'assets/icons/house.svg',
    'assets/icons/broadcast.svg',
    'assets/icons/film-strip.svg',
    'assets/icons/monitor-play.svg',
    'assets/icons/user.svg',
  ];

  static const List<Widget> _screens = [
    StartScreen(),
    LiveTvScreen(),
    MoviesScreen(),
    SeriesScreen(),
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

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768;
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
        ? colorScheme.primary
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

  // Desktop/Web Navigation (oben)
  Widget _buildDesktopAppBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withAlpha(25),
              width: 1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              // Logo & App Name
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/television.svg',
                    width: 32,
                    height: 32,
                    colorFilter: ColorFilter.mode(
                      colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'IPTV Player',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 48),

              // Navigation Tabs (ohne Profil)
              Row(
                children: List.generate(4, (index) {
                  final isSelected = _selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 32),
                    child: GestureDetector(
                      onTap: () => _onItemTapped(index),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _tabLabels[index],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withAlpha(150),
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            height: 2,
                            width: isSelected ? 36 : 0,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),

              const Spacer(),

              // Such-Icon
              GestureDetector(
                onTap: _openSearch,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/magnifying-glass.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onSurface.withAlpha(150),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Profil Icon rechts
              GestureDetector(
                onTap: () => _onItemTapped(4),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 4
                        ? colorScheme.primary.withAlpha(25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/user.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      _selectedIndex == 4
                          ? colorScheme.primary
                          : colorScheme.onSurface.withAlpha(150),
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
                          color: colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(75),
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
                                      color: colorScheme.primary,
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
    final isDesktop = kIsWeb && _isDesktop(context);
    return Scaffold(
      appBar: isDesktop
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 70,
              flexibleSpace: _buildDesktopAppBar(),
            )
          : null,
      extendBody: false,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: isDesktop ? const NeverScrollableScrollPhysics() : null,
        children: _screens,
      ),
      bottomNavigationBar: isDesktop ? null : _buildMobileBottomNavigation(),
    );
  }
}
