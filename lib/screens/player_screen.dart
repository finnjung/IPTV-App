import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/watch_progress.dart';
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

  // Für Doppeltippen
  DateTime? _lastTapLeft;
  DateTime? _lastTapRight;
  bool _showSkipLeft = false;
  bool _showSkipRight = false;

  // Animation Controllers
  late AnimationController _skipLeftController;
  late AnimationController _skipRightController;

  // Watch Progress
  Timer? _saveProgressTimer;
  WatchProgress? _existingProgress;
  bool _hasShownResumeDialog = false;
  late XtreamService _xtreamService;

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

    _initPlayer();
  }

  void _checkExistingProgress() {
    if (widget.contentId == null) return;
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

              // Show resume dialog once when video starts
              if (!_hasShownResumeDialog && _existingProgress != null) {
                _hasShownResumeDialog = true;
                _showResumeDialog();
              }
            } else {
              _cancelHideControlsTimer();
              _showControls();
            }
          });
        }
      });

      _player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() => _isLoading = buffering);
        }
      });

      await _player.open(Media(widget.streamUrl));
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
    if (widget.contentId == null) return;

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
    if (widget.contentId == null) return;

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
              backgroundColor: Theme.of(context).colorScheme.primary,
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
    _skipLeftController.dispose();
    _skipRightController.dispose();

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

  void _toggleControls() {
    if (_controlsVisible) {
      setState(() => _controlsVisible = false);
      _cancelHideControlsTimer();
    } else {
      _showControls();
    }
  }

  void _handleTapLeft() {
    final now = DateTime.now();
    if (_lastTapLeft != null &&
        now.difference(_lastTapLeft!).inMilliseconds < 300) {
      // Doppeltippen erkannt - 10 Sekunden zurück
      _skipBackward();
      _lastTapLeft = null;
    } else {
      _lastTapLeft = now;
      // Nach kurzer Zeit Controls togglen wenn kein zweiter Tap
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_lastTapLeft != null) {
          _toggleControls();
          _lastTapLeft = null;
        }
      });
    }
  }

  void _handleTapRight() {
    final now = DateTime.now();
    if (_lastTapRight != null &&
        now.difference(_lastTapRight!).inMilliseconds < 300) {
      // Doppeltippen erkannt - 10 Sekunden vor
      _skipForward();
      _lastTapRight = null;
    } else {
      _lastTapRight = now;
      // Nach kurzer Zeit Controls togglen wenn kein zweiter Tap
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_lastTapRight != null) {
          _toggleControls();
          _lastTapRight = null;
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video
          Center(
            child: Video(
              controller: _controller,
              controls: NoVideoControls,
            ),
          ),

          // Tap-Bereiche für Doppeltippen
          Row(
            children: [
              // Linke Hälfte - Zurück
              Expanded(
                child: GestureDetector(
                  onTap: _handleTapLeft,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Rechte Hälfte - Vor
              Expanded(
                child: GestureDetector(
                  onTap: _handleTapRight,
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
                  CircularProgressIndicator(
                    color: colorScheme.primary,
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

          // Error
          if (_error != null) _buildErrorWidget(colorScheme),

          // Großer Titel bei Pause (Netflix-Style)
          if (_isPaused && !_isLoading && _error == null)
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black.withAlpha(150),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle!,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(150),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

                      // Center controls (nur wenn nicht pausiert - dann ist der Titel dort)
                      if (!_isPaused) _buildCenterControls(colorScheme),

                      const Spacer(),

                      // Bottom controls mit Seek-Bar
                      _buildBottomControls(colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Wiedergabefehler',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zurück'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
        ],
      ),
    );
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

        // Play/Pause
        StreamBuilder<bool>(
          stream: _player.stream.playing,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return GestureDetector(
              onTap: () {
                if (playing) {
                  _player.pause();
                } else {
                  _player.play();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  playing
                      ? 'assets/icons/pause.svg'
                      : 'assets/icons/play.svg',
                  width: 40,
                  height: 40,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            );
          },
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
                          activeTrackColor: colorScheme.primary,
                          inactiveTrackColor: Colors.white.withAlpha(75),
                          thumbColor: colorScheme.primary,
                          overlayColor: colorScheme.primary.withAlpha(50),
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

          const SizedBox(height: 8),

          // Pause-Button unten (wenn pausiert)
          if (_isPaused)
            StreamBuilder<bool>(
              stream: _player.stream.playing,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return GestureDetector(
                  onTap: () {
                    if (playing) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/play.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fortsetzen',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
