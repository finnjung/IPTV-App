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

  // Live TV Channel Switching (alphabetisch sortiert)
  List<_LiveChannel> _allLiveChannels = [];
  int _currentChannelIndex = 0;
  String _currentTitle = '';
  String _currentStreamUrl = '';
  String? _currentContentId;
  String? _currentImageUrl;

  // Volume & Playback Speed
  double _volume = 1.0;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;

  // Volume/Speed Overlay
  String? _overlayText;
  Timer? _overlayTimer;

  // Cursor auto-hide (Desktop)
  bool _cursorVisible = true;
  Timer? _hideCursorTimer;

  // Stream subscriptions (für sauberes Cleanup)
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _bufferingSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize current channel info
    _currentTitle = widget.title;
    _currentStreamUrl = widget.streamUrl;
    _currentContentId = widget.contentId;
    _currentImageUrl = widget.imageUrl;

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

    // Load all live channels for channel switching (only for live content)
    if (widget.contentType == ContentType.live) {
      _loadLiveChannels();
    }

    // Check for existing progress
    _checkExistingProgress();

    // Check fullscreen status on desktop
    _checkFullscreenStatus();

    _initPlayer();
  }

  void _loadLiveChannels() {
    // Verwende die bereits geladene und sortierte Liste aus liveTvScreenContent
    final content = _xtreamService.liveTvScreenContent;
    if (content == null || content.allStreamsSorted.isEmpty) return;

    // Liste ist bereits alphabetisch sortiert
    _allLiveChannels = content.allStreamsSorted.map((stream) {
      final url = _xtreamService.getLiveStreamUrl(stream);
      return _LiveChannel(
        title: stream.name ?? 'Unbekannt',
        streamUrl: url ?? '',
        contentId: 'live_${stream.streamId}',
        imageUrl: stream.streamIcon,
      );
    }).where((ch) => ch.streamUrl.isNotEmpty).toList();

    // Aktuellen Kanal in der Liste finden (anhand der contentId)
    if (widget.contentId != null) {
      _currentChannelIndex = _allLiveChannels.indexWhere(
        (ch) => ch.contentId == widget.contentId,
      );
      if (_currentChannelIndex < 0) _currentChannelIndex = 0;
    }
  }

  void _checkExistingProgress() {
    // Kein Weiterschauen bei Live-TV
    if (widget.contentId == null || widget.contentType == ContentType.live) return;
    _existingProgress = _xtreamService.getWatchProgress(widget.contentId!);
  }

  void _cancelStreamSubscriptions() {
    _errorSubscription?.cancel();
    _playingSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _errorSubscription = null;
    _playingSubscription = null;
    _bufferingSubscription = null;
  }

  Future<void> _initPlayer() async {
    // Cancel existing subscriptions to prevent listener accumulation
    _cancelStreamSubscriptions();

    try {
      debugPrint('Playing URL: ${widget.streamUrl}');

      _errorSubscription = _player.stream.error.listen((error) {
        debugPrint('Player error: $error');

        // Nicht-fatale Fehler ignorieren (besonders bei Live-Streams)
        final ignorableErrors = [
          'Cannot seek',
          'force-seekable',
          'seekable',
        ];

        final isIgnorable = ignorableErrors.any(
          (e) => error.toLowerCase().contains(e.toLowerCase()),
        );

        if (isIgnorable) {
          debugPrint('Ignoring non-fatal error: $error');
          return;
        }

        if (mounted) {
          setState(() {
            _error = error;
            _isLoading = false;
          });
        }
      });

      _playingSubscription = _player.stream.playing.listen((playing) {
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

              // Cursor beim Pausieren anzeigen
              _hideCursorTimer?.cancel();
              setState(() => _cursorVisible = true);

              // Sync Play/Pause animation: zeige Play-Icon (Video pausiert)
              _playPauseController.reverse();

              // Start pause title timer (3 seconds delay)
              _pauseTitleTimer?.cancel();
              _pauseTitleTimer = Timer(const Duration(seconds: 3), () {
                if (mounted && _isPaused) {
                  setState(() {
                    _showPauseTitle = true;
                    _controlsVisible = false; // Controls ausblenden wenn Titel erscheint
                    _cursorVisible = false; // Cursor auch ausblenden
                  });
                  _pauseTitleController.forward();
                }
              });
            }
          });
        }
      });

      _bufferingSubscription = _player.stream.buffering.listen((buffering) {
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
              _seekToResumePosition();
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

  Future<void> _seekToResumePosition() async {
    if (_existingProgress == null) {
      _player.play();
      return;
    }

    final targetPosition = _existingProgress!.position;

    // Kurz warten bis der Player stabil ist
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Seek ausführen
    await _player.seek(targetPosition);

    // Nochmal kurz warten und dann Position überprüfen
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;

    // Falls der Seek nicht geklappt hat, nochmal versuchen
    final currentPos = _player.state.position;
    final diff = (currentPos.inSeconds - targetPosition.inSeconds).abs();

    if (diff > 5) {
      // Position weicht mehr als 5 Sekunden ab, erneut versuchen
      debugPrint('Seek retry: current=$currentPos, target=$targetPosition');
      await _player.seek(targetPosition);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      _player.play();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _saveProgressTimer?.cancel();
    _pauseTitleTimer?.cancel();
    _overlayTimer?.cancel();
    _hideCursorTimer?.cancel();
    _skipLeftController.dispose();
    _skipRightController.dispose();
    _pauseTitleController.dispose();
    _playPauseController.dispose();
    _focusNode.dispose();

    // Cancel stream subscriptions before disposing player
    _cancelStreamSubscriptions();

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
    setState(() {
      _controlsVisible = true;
      _cursorVisible = true; // Cursor auch anzeigen
    });

    // Pause-Titel smooth ausblenden wenn Controls angezeigt werden
    if (_showPauseTitle) {
      _pauseTitleController.animateTo(0, duration: const Duration(milliseconds: 300)).then((_) {
        if (mounted) setState(() => _showPauseTitle = false);
      });
    }

    if (!_isPaused) {
      _startHideControlsTimer();
      _startHideCursorTimer();
    }
  }

  void _showCursor() {
    if (!_cursorVisible) {
      setState(() => _cursorVisible = true);
    }
    _startHideCursorTimer();
  }

  void _startHideCursorTimer() {
    _hideCursorTimer?.cancel();
    // Cursor ausblenden wenn Video spielt
    if (!_isPaused) {
      _hideCursorTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isPaused) {
          setState(() => _cursorVisible = false);
        }
      });
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

  void _showOverlay(String text) {
    setState(() => _overlayText = text);
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _overlayText = null);
    });
  }

  void _setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _player.setVolume(_volume * 100);
    _isMuted = _volume == 0;
    final percent = (_volume * 100).round();
    _showOverlay('Lautstärke: $percent%');
  }

  void _toggleMute() {
    if (_isMuted) {
      _isMuted = false;
      _player.setVolume(_volume * 100);
      _showOverlay('Ton an');
    } else {
      _isMuted = true;
      _player.setVolume(0);
      _showOverlay('Stumm');
    }
    setState(() {});
  }

  void _setPlaybackSpeed(double speed) {
    _playbackSpeed = speed.clamp(0.25, 2.0);
    _player.setRate(_playbackSpeed);
    _showOverlay('${_playbackSpeed}x');
    setState(() {});
  }

  void _seekToPercent(int percent) {
    final duration = _player.state.duration;
    if (duration.inSeconds < 1) return;
    final position = Duration(milliseconds: (duration.inMilliseconds * percent / 100).round());
    _player.seek(position);
    _showOverlay('$percent%');
  }

  // Channel switching (Live TV only - alphabetisch sortiert)
  bool get _hasChannels => _allLiveChannels.length > 1;

  void _switchToChannel(int index) {
    if (!_hasChannels) return;

    // Wrap around
    if (index < 0) index = _allLiveChannels.length - 1;
    if (index >= _allLiveChannels.length) index = 0;

    if (index == _currentChannelIndex) return;

    final channel = _allLiveChannels[index];
    setState(() {
      _currentChannelIndex = index;
      _currentTitle = channel.title;
      _currentStreamUrl = channel.streamUrl;
      _currentContentId = channel.contentId;
      _currentImageUrl = channel.imageUrl;
      _isLoading = true;
      _error = null;
    });

    // Reload player with new URL
    _reloadPlayer();
  }

  void _nextChannel() {
    _switchToChannel(_currentChannelIndex + 1);
  }

  void _previousChannel() {
    _switchToChannel(_currentChannelIndex - 1);
  }

  Future<void> _reloadPlayer() async {
    try {
      // Stop current playback to avoid race conditions with MPV
      await _player.stop();

      String cleanUrl = _currentStreamUrl;
      while (cleanUrl.endsWith('.') || cleanUrl.endsWith(' ')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      debugPrint('Playing URL: $cleanUrl');
      debugPrint('Clean URL: $cleanUrl');
      await _player.open(Media(cleanUrl));
    } catch (e) {
      debugPrint('Channel switch error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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

    final key = event.logicalKey;

    // Leertaste oder K = Play/Pause
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _handleTapPlayPause();
      return KeyEventResult.handled;
    }

    // Pfeiltaste links oder J = 10 Sek zurück
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      _skipBackward();
      return KeyEventResult.handled;
    }

    // Pfeiltaste rechts oder L = 10 Sek vor
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
      _skipForward();
      return KeyEventResult.handled;
    }

    // Pfeiltaste hoch = Lautstärke +10%
    if (key == LogicalKeyboardKey.arrowUp) {
      _setVolume(_volume + 0.1);
      return KeyEventResult.handled;
    }

    // Pfeiltaste runter = Lautstärke -10%
    if (key == LogicalKeyboardKey.arrowDown) {
      _setVolume(_volume - 0.1);
      return KeyEventResult.handled;
    }

    // M = Stummschalten
    if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
      return KeyEventResult.handled;
    }

    // F = Vollbild ein/aus
    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }

    // < (Komma) = Geschwindigkeit langsamer
    if (key == LogicalKeyboardKey.comma) {
      _setPlaybackSpeed(_playbackSpeed - 0.25);
      return KeyEventResult.handled;
    }

    // > (Punkt) = Geschwindigkeit schneller
    if (key == LogicalKeyboardKey.period) {
      _setPlaybackSpeed(_playbackSpeed + 0.25);
      return KeyEventResult.handled;
    }

    // 0-9 = Zu Position springen
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _seekToPercent(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _seekToPercent(10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _seekToPercent(20);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      _seekToPercent(30);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      _seekToPercent(40);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      _seekToPercent(50);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      _seekToPercent(60);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      _seekToPercent(70);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      _seekToPercent(80);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      _seekToPercent(90);
      return KeyEventResult.handled;
    }

    // Channel +/- (Live TV only)
    if (_hasChannels) {
      // Page Up / N = nächster Kanal
      if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.keyN) {
        _nextChannel();
        return KeyEventResult.handled;
      }
      // Page Down / P = vorheriger Kanal
      if (key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.keyP) {
        _previousChannel();
        return KeyEventResult.handled;
      }
    }

    // Escape = Vollbild verlassen (falls aktiv), sonst Zurück
    if (key == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _toggleFullscreen();
      } else {
        Navigator.pop(context);
      }
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
        cursor: _cursorVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onEnter: (_) {
          _showControls();
          _showCursor();
        },
        onHover: (_) {
          _showCursor();
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

          // Volume/Speed Overlay
          if (_overlayText != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _overlayText!,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
                    // Titel - mittig positioniert mit cineastischer Schrift
                    Positioned.fill(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Opacity(
                            opacity: _pauseTitleController.value * 0.55,
                            child: Text(
                              _currentTitle.toUpperCase(),
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
                          ),
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
              child: GestureDetector(
                // Tap auf leeren Bereich = Play/Pause
                onTap: _handleTapPlayPause,
                behavior: HitTestBehavior.translucent,
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

                        // Center controls (nicht beim Laden, Fehler oder Pause-Titel)
                        if (!_isLoading && _error == null && !_showPauseTitle) _buildCenterControls(colorScheme),

                        const Spacer(),

                        // Bottom controls mit Seek-Bar (nicht bei Fehler)
                        if (_error == null) _buildBottomControls(colorScheme),
                      ],
                    ),
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
    } else if (errorMessage.length > 150) {
      errorMessage = '${errorMessage.substring(0, 147)}...';
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return GestureDetector(
      // Verhindert, dass Taps zu den darunterliegenden Controls durchgereicht werden
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withAlpha(230),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: isCompact ? 20 : 32,
                  vertical: 24,
                ),
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey[850]!,
                      Colors.grey[900]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withAlpha(15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header mit Icon
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isCompact ? 24 : 32),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withAlpha(15),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withAlpha(25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.error.withAlpha(50),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.wifi_off_rounded,
                              color: colorScheme.error,
                              size: isCompact ? 36 : 44,
                            ),
                          ),
                          SizedBox(height: isCompact ? 16 : 20),
                          Text(
                            'Wiedergabefehler',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: isCompact ? 18 : 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body mit Fehlermeldung
                    Padding(
                      padding: EdgeInsets.all(isCompact ? 20 : 24),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withAlpha(8),
                              ),
                            ),
                            child: Text(
                              errorMessage,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withAlpha(180),
                                fontSize: isCompact ? 13 : 14,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          SizedBox(height: isCompact ? 20 : 24),

                          // Buttons - vertikal gestapelt für bessere Mobile-Kompatibilität
                          Column(
                            children: [
                              // Erneut versuchen (Primary)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _error = null;
                                      _isLoading = true;
                                    });
                                    _initPlayer();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.refresh_rounded, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Erneut versuchen',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Zurück (Secondary)
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white.withAlpha(180),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_back_rounded,
                                        size: 18,
                                        color: Colors.white.withAlpha(150),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Zurück',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          color: Colors.white.withAlpha(180),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
    final contentId = _currentContentId ?? widget.contentId;
    if (contentId != null) {
      if (widget.contentType == ContentType.series) {
        // Format: series_seriesId_season_episode -> extrahiere series_seriesId
        final parts = contentId.split('_');
        if (parts.length >= 2) {
          favoriteId = '${parts[0]}_${parts[1]}';
        }
      } else {
        favoriteId = contentId;
      }
    }

    final isFavorite = favoriteId != null && xtreamService.isFavorite(favoriteId);

    // Extra top padding für macOS Titelleiste (Window-Buttons)
    final isMacOS = !kIsWeb && Platform.isMacOS;
    final topPadding = isMacOS ? 28.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
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
                  _currentTitle,
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
          if (contentId != null)
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
    final isLive = widget.contentType == ContentType.live;

    // Bei Live-Streams: Channel-Buttons mit LIVE-Badge in der Mitte
    if (isLive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous channel (nur wenn Kanäle vorhanden)
            if (_hasChannels)
              IconButton(
                onPressed: _previousChannel,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(30),
                ),
                icon: SvgPicture.asset(
                  'assets/icons/caret-left.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            if (_hasChannels) const SizedBox(width: 16),
            // LIVE Badge (mittig)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (_hasChannels) const SizedBox(width: 16),
            // Next channel (nur wenn Kanäle vorhanden)
            if (_hasChannels)
              IconButton(
                onPressed: _nextChannel,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(30),
                ),
                icon: SvgPicture.asset(
                  'assets/icons/caret-right.svg',
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

    // Bei VOD: Seekbar und Zeiten anzeigen
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

/// Internal class for live channel info
class _LiveChannel {
  final String title;
  final String streamUrl;
  final String? contentId;
  final String? imageUrl;

  const _LiveChannel({
    required this.title,
    required this.streamUrl,
    this.contentId,
    this.imageUrl,
  });
}
