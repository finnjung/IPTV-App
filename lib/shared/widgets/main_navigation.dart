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
import '../../widgets/hero_banner.dart';

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

  // TV Navigation
  // Navigation order: Start(0) -> Filme(1) -> Serien(2) -> Live(3) -> Search -> Profil(4)
  final FocusNode _mainFocusNode = FocusNode();
  int _focusedNavIndex = 0; // 0-3 for main tabs, 4 for profile
  bool _isSearchFocused = false; // Track if search icon is focused
  final List<FocusNode> _navFocusNodes = List.generate(5, (_) => FocusNode());
  final FocusNode _searchFocusNode = FocusNode();

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

    // Start-Tab FocusNode für Navigation vom Play-Button registrieren
    HeroBannerFocus.startTabFocusNode = _navFocusNodes[0];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideLineController.dispose();
    _mainFocusNode.dispose();
    _searchFocusNode.dispose();
    for (final node in _navFocusNodes) {
      node.dispose();
    }
    // FocusNode-Referenz aufräumen
    HeroBannerFocus.startTabFocusNode = null;
    super.dispose();
  }

  // TV/Keyboard Navigation Handler
  // Navigation order: Start(0) -> Filme(1) -> Serien(2) -> Live(3) -> Search -> Profil(4)
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Prüfe ob der Fokus aktuell in der Navigation ist
    final isInNav = _navFocusNodes.any((n) => n.hasFocus) ||
        _searchFocusNode.hasFocus;

    // Horizontale Navigation zwischen Tabs - NUR wenn Fokus in der Nav ist
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (!isInNav) return KeyEventResult.ignored; // Event an Content weitergeben

      setState(() {
        if (_focusedNavIndex == 4 && !_isSearchFocused) {
          // Von Profil zu Suche
          _isSearchFocused = true;
          _searchFocusNode.requestFocus();
        } else if (_isSearchFocused) {
          // Von Suche zu Live (Index 3)
          _isSearchFocused = false;
          _focusedNavIndex = 3;
          _navFocusNodes[3].requestFocus();
        } else if (_focusedNavIndex > 0) {
          // Zwischen Tabs navigieren
          _focusedNavIndex--;
          _navFocusNodes[_focusedNavIndex].requestFocus();
        } else if (_focusedNavIndex == 0 && _selectedIndex == 0) {
          // Von Start-Tab zum HeroBanner Play-Button (nur auf Start-Screen)
          if (HeroBannerFocus.hasPlayButton) {
            HeroBannerFocus.requestPlayButtonFocus();
          }
        }
      });
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // Vom Play-Button zurück zum Start-Tab
      if (_selectedIndex == 0 && HeroBannerFocus.playButtonFocusNode?.hasFocus == true) {
        _navFocusNodes[0].requestFocus();
        setState(() {
          _focusedNavIndex = 0;
          _isSearchFocused = false;
        });
        return KeyEventResult.handled;
      }
      if (!isInNav) return KeyEventResult.ignored; // Event an Content weitergeben

      setState(() {
        if (_focusedNavIndex < 3) {
          // Zwischen Tabs 0-3 navigieren
          _focusedNavIndex++;
          _navFocusNodes[_focusedNavIndex].requestFocus();
        } else if (_focusedNavIndex == 3 && !_isSearchFocused) {
          // Von Live (Index 3) zu Suche
          _isSearchFocused = true;
          _searchFocusNode.requestFocus();
        } else if (_isSearchFocused) {
          // Von Suche zu Profil (Index 4)
          _isSearchFocused = false;
          _focusedNavIndex = 4;
          _navFocusNodes[4].requestFocus();
        }
      });
      return KeyEventResult.handled;
    }

    // Vertikale Navigation: Von Nav zum Screen-Inhalt und zurück
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (isInNav) {
        // Auf dem StartScreen: Zuerst den Play-Button im HeroBanner fokussieren
        if (_selectedIndex == 0 && HeroBannerFocus.hasPlayButton) {
          HeroBannerFocus.requestPlayButtonFocus();
          setState(() {});
          return KeyEventResult.handled;
        }
        // Sonst: Versuche den Fokus nach unten zum Screen-Inhalt zu bewegen
        final moved = FocusScope.of(context).focusInDirection(TraversalDirection.down);
        if (moved) {
          // Fokus hat die Nav verlassen - State aktualisieren
          setState(() {});
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (!isInNav) {
        // Wir sind im Screen-Inhalt, versuche zurück zur Navigation
        final moved = FocusScope.of(context).focusInDirection(TraversalDirection.up);
        if (moved) {
          return KeyEventResult.handled;
        } else {
          // Fallback: Fokussiere den aktuell ausgewählten Tab
          final navIndex = _selectedIndex < 4 ? _selectedIndex : 0;
          _navFocusNodes[navIndex].requestFocus();
          setState(() {
            _focusedNavIndex = navIndex;
            _isSearchFocused = false;
          });
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    // Tab-Wechsel mit Zahlen 1-5
    if (event.logicalKey.keyId >= LogicalKeyboardKey.digit1.keyId &&
        event.logicalKey.keyId <= LogicalKeyboardKey.digit5.keyId) {
      final index = event.logicalKey.keyId - LogicalKeyboardKey.digit1.keyId;
      _onItemTapped(index);
      return KeyEventResult.handled;
    }

    // Suche mit S-Taste
    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      _openSearch();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SearchScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
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
      child: Container(
        // Dezenter Gradient für bessere Lesbarkeit bei hellen Bildern
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withAlpha(80),
              Colors.black.withAlpha(40),
              Colors.black.withAlpha(15),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
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
                  final isFocused = _navFocusNodes[index].hasFocus;
                  return Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Focus(
                      focusNode: _navFocusNodes[index],
                      onFocusChange: (hasFocus) {
                        // Immer setState aufrufen um visuellen Fokus-Zustand zu aktualisieren
                        setState(() {
                          if (hasFocus) {
                            _focusedNavIndex = index;
                          }
                        });
                      },
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                             event.logicalKey == LogicalKeyboardKey.enter ||
                             event.logicalKey == LogicalKeyboardKey.space)) {
                          _onItemTapped(index);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: GestureDetector(
                        onTap: () => _onItemTapped(index),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected || isFocused
                                ? Colors.white.withAlpha(isFocused ? 40 : 20)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isFocused
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Text(
                            _tabLabels[index],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isSelected || isFocused
                                  ? Colors.white
                                  : Colors.white.withAlpha(200),
                              fontWeight: isSelected || isFocused ? FontWeight.w600 : FontWeight.w500,
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
                    ),
                  );
                }),
              ),

              const SizedBox(width: 20),

              // Such-Icon
              Focus(
                focusNode: _searchFocusNode,
                onFocusChange: (hasFocus) {
                  // Immer setState aufrufen um visuellen Fokus-Zustand zu aktualisieren
                  setState(() {
                    if (hasFocus) {
                      _isSearchFocused = true;
                    }
                  });
                },
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.select ||
                       event.logicalKey == LogicalKeyboardKey.enter ||
                       event.logicalKey == LogicalKeyboardKey.space)) {
                    _openSearch();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (context) {
                    final isFocused = _searchFocusNode.hasFocus;
                    return GestureDetector(
                      onTap: _openSearch,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(isFocused ? 40 : 15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFocused ? Colors.white : Colors.white.withAlpha(30),
                            width: isFocused ? 2 : 1,
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
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Profil Icon
              Focus(
                focusNode: _navFocusNodes[4],
                onFocusChange: (hasFocus) {
                  // Immer setState aufrufen um visuellen Fokus-Zustand zu aktualisieren
                  setState(() {
                    if (hasFocus) {
                      _focusedNavIndex = 4;
                    }
                  });
                },
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.select ||
                       event.logicalKey == LogicalKeyboardKey.enter ||
                       event.logicalKey == LogicalKeyboardKey.space)) {
                    _onItemTapped(4);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (context) {
                    final isFocused = _navFocusNodes[4].hasFocus;
                    return GestureDetector(
                      onTap: () => _onItemTapped(4),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _selectedIndex == 4 || isFocused
                              ? Colors.white.withAlpha(isFocused ? 40 : 30)
                              : Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFocused ? Colors.white : Colors.white.withAlpha(30),
                            width: isFocused ? 2 : 1,
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
                    );
                  },
                ),
              ),
            ],
          ),
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
                    child: Focus(
                      focusNode: _navFocusNodes[index],
                      onFocusChange: (hasFocus) {
                        // Immer setState aufrufen um visuellen Fokus-Zustand zu aktualisieren
                        setState(() {
                          if (hasFocus) {
                            _focusedNavIndex = index;
                          }
                        });
                      },
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.select ||
                             event.logicalKey == LogicalKeyboardKey.enter ||
                             event.logicalKey == LogicalKeyboardKey.space)) {
                          _onItemTapped(index);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(
                        builder: (context) {
                          final isFocused = _navFocusNodes[index].hasFocus;
                          return GestureDetector(
                            onTap: () => _onItemTapped(index),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 70,
                              decoration: BoxDecoration(
                                color: isFocused
                                    ? colorScheme.primary.withAlpha(30)
                                    : Colors.transparent,
                                border: isFocused
                                    ? Border.all(color: colorScheme.primary, width: 2)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildTabIcon(index, isSelected || isFocused),
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
                          );
                        },
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
    return Focus(
      focusNode: _mainFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
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
      ),
    );
  }
}
