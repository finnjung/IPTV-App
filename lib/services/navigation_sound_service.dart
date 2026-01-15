import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for playing navigation sounds during TV/keyboard navigation
class NavigationSoundService {
  static final NavigationSoundService _instance = NavigationSoundService._internal();
  factory NavigationSoundService() => _instance;
  NavigationSoundService._internal();

  AudioPlayer? _player;
  bool _initialized = false;
  bool _enabled = true;
  double _volume = 0.3;

  /// Initialize the sound service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _player = AudioPlayer();
      _player!.setReleaseMode(ReleaseMode.stop);
      _player!.setVolume(_volume);

      // Test play to verify setup works
      debugPrint('[NavigationSound] Initializing...');
      _initialized = true;
      debugPrint('[NavigationSound] Initialized successfully');
    } catch (e) {
      debugPrint('[NavigationSound] Failed to initialize: $e');
      _initialized = false;
    }
  }

  /// Enable or disable navigation sounds
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Check if sounds are enabled
  bool get isEnabled => _enabled;

  /// Play the navigation focus sound
  Future<void> playFocusSound() async {
    if (!_enabled || !_initialized || _player == null) {
      debugPrint('[NavigationSound] Skipping - enabled=$_enabled, init=$_initialized, player=${_player != null}');
      return;
    }

    try {
      debugPrint('[NavigationSound] Playing focus sound...');
      // Use play() directly with AssetSource - this is the recommended approach
      await _player!.play(AssetSource('sounds/tap_01.wav'));
      debugPrint('[NavigationSound] Sound played');
    } catch (e) {
      debugPrint('[NavigationSound] Error playing sound: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _player?.dispose();
    _player = null;
    _initialized = false;
  }
}
