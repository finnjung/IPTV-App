import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../models/watch_progress.dart';
import '../models/favorite.dart';
import '../services/xtream_service.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String streamUrl;
  final String? contentId; // Für Watch-Progress
  final String? imageUrl;
  final ContentType contentType;

  const PlayerScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.streamUrl,
    this.contentId,
    this.imageUrl,
    this.contentType = ContentType.movie,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late final Player _player;
  late final VideoController _controller;
  bool _isLoading = true;
  String? _error;
  bool _controlsVisible = true;
  bool _isPaused = false;
  Timer? _hideControlsTimer;

  // Skip-Animation
  bool _showSkipLeft = false;
  bool _showSkipRight = false;

  // Pause-Titel Animation (verzögert nach 3 Sekunden)
  bool _showPauseTitle = false;
  Timer? _pauseTitleTimer;

  // Fullscreen (Desktop)
  bool _isFullscreen = false;

  // Animation Controllers
  late AnimationController _skipLeftController;
  late AnimationController _skipRightController;
  late AnimationController _pauseTitleController;
  late AnimationController _playPauseController;

  // Watch Progress
  Timer? _saveProgressTimer;
  WatchProgress? _existingProgress;
  bool _hasShownResumeDialog = false;
  late XtreamService _xtreamService;

  // Keyboard Focus
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Animation Controllers für Skip-Feedback
    _skipLeftController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _skipRightController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pauseTitleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Play/Pause Lottie Animation Controller
    // Animation: Frame 5 = Play-Icon, Frame 27 = Pause-Icon
    // Wir begrenzen den Controller auf diesen Bereich
    _playPauseController = AnimationController(
      value: 5 / 67, // Start bei Play-Icon (Video ist initial pausiert)
      lowerBound: 5 / 67,  // Frame 5 = Play-Icon
      upperBound: 27 / 67, // Frame 27 = Pause-Icon
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Set landscape orientation for video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player();
    _controller = VideoController(_player);

    // Cache the service for later use in dispose
    _xtreamService = context.read<XtreamService>();

    // Check for existing progress
    _checkExistingProgress();

    // Check fullscreen status on desktop
    _checkFullscreenStatus();

    _initPlayer();
  }

  void _checkExistingProgress() {
    // Kein Weiterschauen bei Live-TV
    if (widget.contentId == null || widget.contentType == ContentType.live) return;
    _existingProgress = _xtreamService.getWatchProgress(widget.contentId!);
  }

  Future<void> _initPlayer() async {
    try {
      debugPrint('Playing URL: ${widget.streamUrl}');

      _player.stream.error.listen((error) {
        debugPrint('Player error: $error');
        if (mounted) {
          setState(() {
            _error = error;
            _isLoading = false;
          });
        }
      });

      _player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPaused = !playing;
            if (playing) {
              _isLoading = false;
              _startHideControlsTimer();
              _startSaveProgressTimer();

              // Sync Play/Pause animation: zeige Pause-Icon (Video spielt)
              _playPauseController.forward();

              // Cancel pause title animation
              _pauseTitleTimer?.cancel();
              _showPauseTitle = false;
              _pauseTitleController.reset();

              // Show resume dialog once when video starts
              if (!_hasShownResumeDialog && _existingProgress != null) {
                _hasShownResumeDialog = true;
                _showResumeDialog();
              }
            } else {
              _cancelHideControlsTimer();
              _showControls();

              // Sync Play/Pause animation: zeige Play-Icon (Video pausiert)
              _playPauseController.reverse();

              // Start pause title timer (3 seconds delay)
              _pauseTitleTimer?.cancel();
              _pauseTitleTimer = Timer(const Duration(seconds: 3), () {
                if (mounted && _isPaused) {
                  setState(() => _showPauseTitle = true);
                  _pauseTitleController.forward();
                }
              });
            }
          });
        }
      });

      _player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() => _isLoading = buffering);
        }
      });

      // URL bereinigen (trailing Punkt entfernen, kann bei manchen Quellen vorkommen)
      String cleanUrl = widget.streamUrl;
      while (cleanUrl.endsWith('.') || cleanUrl.endsWith(' ')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      debugPrint('Clean URL: $cleanUrl');

      await _player.open(Media(cleanUrl));
    } catch (e) {
      debugPrint('Player init error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _startSaveProgressTimer() {
    _saveProgressTimer?.cancel();
    // Save progress every 10 seconds
    _saveProgressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _saveCurrentProgress();
    });
  }

  Future<void> _saveCurrentProgress() async {
    // Kein Progress-Speichern bei Live-TV
    if (widget.contentId == null || widget.contentType == ContentType.live) return;

    final position = _player.state.position;
    final duration = _player.state.duration;

    // Don't save if duration is unknown or too short
    if (duration.inSeconds < 60) return;

    final progress = WatchProgress(
      id: widget.contentId!,
      title: widget.title,
      subtitle: widget.subtitle,
      streamUrl: widget.streamUrl,
      imageUrl: widget.imageUrl,
      contentType: widget.contentType,
      position: position,
      duration: duration,
      lastWatched: DateTime.now(),
    );

    await _xtreamService.updateWatchProgress(progress);
  }

  void _saveFinalProgress() {
    // Kein Progress-Speichern bei Live-TV
    if (widget.contentId == null || widget.contentType == ContentType.live) return;

    final position = _player.state.position;
    final duration = _player.state.duration;

    // Don't save if duration is unknown or too short
    if (duration.inSeconds < 60) return;

    final progress = WatchProgress(
      id: widget.contentId!,
      title: widget.title,
      subtitle: widget.subtitle,
      streamUrl: widget.streamUrl,
      imageUrl: widget.imageUrl,
      contentType: widget.contentType,
      position: position,
      duration: duration,
      lastWatched: DateTime.now(),
    );

    // Fire and forget - no await needed
    _xtreamService.updateWatchProgress(progress);
  }

  void _showResumeDialog() {
    if (_existingProgress == null) return;

    _player.pause();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Weiterschauen?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Du hast diesen Inhalt bei ${_existingProgress!.formattedPosition} angehalten.\n${_existingProgress!.remainingTime}',
          style: GoogleFonts.poppins(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _player.play();
            },
            child: Text(
              'Von vorne',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _player.seek(_existingProgress!.position);
              _player.play();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: Text(
              'Fortsetzen',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _saveProgressTimer?.cancel();
    _pauseTitleTimer?.cancel();
    _skipLeftController.dispose();
    _skipRightController.dispose();
    _pauseTitleController.dispose();
    _playPauseController.dispose();
    _focusNode.dispose();

    // Save final progress before closing (fire and forget)
    _saveFinalProgress();

    _player.dispose();

    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _startHideControlsTimer() {
    _cancelHideControlsTimer();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isPaused) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _cancelHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    if (!_isPaused) {
      _startHideControlsTimer();
    }
  }

  Future<void> _toggleFullscreen() async {
    // Nur auf Desktop (nicht Web, nicht Mobile)
    if (kIsWeb) return;
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) return;

    try {
      final isCurrentlyFullscreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isCurrentlyFullscreen);
      if (mounted) {
        setState(() => _isFullscreen = !isCurrentlyFullscreen);
      }
    } catch (e) {
      debugPrint('Fullscreen toggle error: $e');
    }
  }

  Future<void> _checkFullscreenStatus() async {
    if (kIsWeb) return;
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) return;

    try {
      await windowManager.ensureInitialized();
      final isFullscreen = await windowManager.isFullScreen();
      if (mounted) {
        setState(() => _isFullscreen = isFullscreen);
      }
    } catch (e) {
      debugPrint('Fullscreen check error: $e');
    }
  }

  void _handleTapPlayPause() {
    // Einfacher Tap = Play/Pause
    // Animation wird über den Player-Stream-Listener synchronisiert
    if (_player.state.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _skipForward() {
    final pos = _player.state.position;
    _player.seek(pos + const Duration(seconds: 10));

    setState(() => _showSkipRight = true);
    _skipRightController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showSkipRight = false);
    });

    _showControls();
  }

  void _skipBackward() {
    final pos = _player.state.position;
    _player.seek(pos - const Duration(seconds: 10));

    setState(() => _showSkipLeft = true);
    _skipLeftController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showSkipLeft = false);
    });

    _showControls();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Nur auf KeyDown reagieren (nicht KeyUp)
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Leertaste = Play/Pause
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _handleTapPlayPause();
      return KeyEventResult.handled;
    }

    // Pfeiltaste links = 10 Sek zurück
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _skipBackward();
      return KeyEventResult.handled;
    }

    // Pfeiltaste rechts = 10 Sek vor
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _skipForward();
      return KeyEventResult.handled;
    }

    // Escape = Zurück
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
        onEnter: (_) => _showControls(),
        onHover: (_) {
          if (!_controlsVisible) _showControls();
        },
        child: Stack(
          children: [
            // Video
            Center(
              child: Video(
                controller: _controller,
                controls: NoVideoControls,
              ),
            ),

            // Tap zum Play/Pause - Doppeltap für Skip
            Row(
              children: [
                // Linke Hälfte - Doppeltap = Zurück
                Expanded(
                  child: GestureDetector(
                    onTap: _handleTapPlayPause,
                    onDoubleTap: _skipBackward,
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Rechte Hälfte - Doppeltap = Vor
                Expanded(
                  child: GestureDetector(
                    onTap: _handleTapPlayPause,
                    onDoubleTap: _skipForward,
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),

          // Skip-Animationen
          if (_showSkipLeft)
            Positioned(
              left: screenWidth * 0.15,
              top: 0,
              bottom: 0,
              child: _buildSkipIndicator(-10, _skipLeftController),
            ),
          if (_showSkipRight)
            Positioned(
              right: screenWidth * 0.15,
              top: 0,
              bottom: 0,
              child: _buildSkipIndicator(10, _skipRightController),
            ),

          // Loading indicator
          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lädt...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Großer Titel bei Pause (nach 3 Sekunden mit Fade-In und Abdunkelung)
          if (_showPauseTitle && _isPaused && !_isLoading && _error == null)
            AnimatedBuilder(
              animation: _pauseTitleController,
              builder: (context, child) {
                return Stack(
                  children: [
                    // Dunkler Overlay
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withAlpha(
                          (180 * _pauseTitleController.value).toInt(),
                        ),
                      ),
                    ),
                    // Titel - oben positioniert mit cineastischer Schrift
                    Positioned(
                      top: 80,
                      left: 32,
                      right: 32,
                      child: Opacity(
                        opacity: _pauseTitleController.value * 0.55,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget.title.toUpperCase(),
                              style: GoogleFonts.anton(
                                color: Colors.white,
                                fontSize: 140,
                                letterSpacing: 1,
                                height: 0.9,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                widget.subtitle!,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          // Controls overlay
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(180),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withAlpha(200),
                    ],
                    stops: const [0.0, 0.25, 0.7, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar
                      _buildTopBar(),

                      const Spacer(),

                      // Center controls (nicht beim Laden oder Fehler)
                      if (!_isLoading && _error == null) _buildCenterControls(colorScheme),

                      const Spacer(),

                      // Bottom controls mit Seek-Bar (nicht bei Fehler)
                      if (_error == null) _buildBottomControls(colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Error - MUSS am Ende des Stacks sein, damit es über allem liegt
          if (_error != null) _buildErrorWidget(colorScheme),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSkipIndicator(int seconds, AnimationController controller) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Opacity(
          opacity: 1.0 - controller.value,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    seconds < 0
                        ? 'assets/icons/rewind.svg'
                        : 'assets/icons/fast-forward.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${seconds.abs()} Sek.',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    // Fehlermeldung kürzen (nur den relevanten Teil anzeigen)
    String errorMessage = _error ?? 'Unbekannter Fehler';
    if (errorMessage.contains('Failed to open')) {
      errorMessage = 'Stream konnte nicht geöffnet werden.\nDer Inhalt ist möglicherweise nicht verfügbar.';
    }

    return GestureDetector(
      // Verhindert, dass Taps zu den darunterliegenden Controls durchgereicht werden
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withAlpha(220),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: colorScheme.error,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Wiedergabefehler',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Erneut versuchen
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _initPlayer();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
                        'Erneut versuchen',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Zurück
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: Text(
                        'Zurück',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final xtreamService = context.watch<XtreamService>();

    // Bestimme Favoriten-ID basierend auf Content-Type
    String? favoriteId;
    if (widget.contentId != null) {
      if (widget.contentType == ContentType.series) {
        // Format: series_seriesId_season_episode -> extrahiere series_seriesId
        final parts = widget.contentId!.split('_');
        if (parts.length >= 2) {
          favoriteId = '${parts[0]}_${parts[1]}';
        }
      } else {
        favoriteId = widget.contentId;
      }
    }

    final isFavorite = favoriteId != null && xtreamService.isFavorite(favoriteId);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: SvgPicture.asset(
              'assets/icons/caret-left.svg',
              width: 28,
              height: 28,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Favoriten-Button
          if (widget.contentId != null)
            IconButton(
              onPressed: () => _toggleFavorite(xtreamService),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
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
          // Fullscreen toggle (nur auf Desktop)
          if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
            IconButton(
              onPressed: _toggleFullscreen,
              icon: SvgPicture.asset(
                _isFullscreen
                    ? 'assets/icons/corners-in.svg'
                    : 'assets/icons/corners-out.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleFavorite(XtreamService xtreamService) {
    if (widget.contentId == null) return;

    Favorite favorite;

    switch (widget.contentType) {
      case ContentType.movie:
        // Extract streamId from movie_123
        final streamId = int.tryParse(widget.contentId!.replaceFirst('movie_', '')) ?? 0;
        favorite = Favorite.fromMovie(
          streamId: streamId,
          title: widget.title,
          imageUrl: widget.imageUrl,
        );
        break;
      case ContentType.series:
        // Extract seriesId from series_123_season_episode
        final parts = widget.contentId!.split('_');
        final seriesId = parts.length >= 2 ? int.tryParse(parts[1]) ?? 0 : 0;
        favorite = Favorite.fromSeries(
          seriesId: seriesId,
          title: widget.title,
          imageUrl: widget.imageUrl,
        );
        break;
      case ContentType.live:
        // Extract streamId from live_123
        final streamId = int.tryParse(widget.contentId!.replaceFirst('live_', '')) ?? 0;
        favorite = Favorite.fromLiveStream(
          streamId: streamId,
          title: widget.title,
          imageUrl: widget.imageUrl,
        );
        break;
    }

    xtreamService.toggleFavorite(favorite);
  }

  Widget _buildCenterControls(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rewind
        IconButton(
          onPressed: _skipBackward,
          iconSize: 48,
          icon: SvgPicture.asset(
            'assets/icons/rewind.svg',
            width: 40,
            height: 40,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
        ),

        const SizedBox(width: 32),

        // Play/Pause mit Lottie Animation
        GestureDetector(
          onTap: _handleTapPlayPause,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Lottie.asset(
              'assets/animations/play_pause.json',
              controller: _playPauseController,
              fit: BoxFit.contain,
            ),
          ),
        ),

        const SizedBox(width: 32),

        // Fast forward
        IconButton(
          onPressed: _skipForward,
          iconSize: 48,
          icon: SvgPicture.asset(
            'assets/icons/fast-forward.svg',
            width: 40,
            height: 40,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Seek-Bar
          StreamBuilder<Duration>(
            stream: _player.stream.position,
            builder: (context, posSnapshot) {
              return StreamBuilder<Duration>(
                stream: _player.stream.duration,
                builder: (context, durSnapshot) {
                  final position = posSnapshot.data ?? Duration.zero;
                  final duration = durSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;

                  return Column(
                    children: [
                      // Seek-Slider
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withAlpha(75),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withAlpha(50),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (value) {
                            final newPosition = Duration(
                              milliseconds:
                                  (value * duration.inMilliseconds).toInt(),
                            );
                            _player.seek(newPosition);
                          },
                          onChangeStart: (_) => _cancelHideControlsTimer(),
                          onChangeEnd: (_) => _startHideControlsTimer(),
                        ),
                      ),

                      // Zeit-Anzeige
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

        ],
      ),
    );
  }
}
