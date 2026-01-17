import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

/// Data model for credentials entered via remote keyboard
class RemoteCredentials {
  final String? serverUrl;
  final String? port;
  final String? username;
  final String? password;
  final bool submitted; // True when user explicitly clicked "Send to TV"
  final String? focusedField; // Currently focused field on phone

  RemoteCredentials({
    this.serverUrl,
    this.port,
    this.username,
    this.password,
    this.submitted = false,
    this.focusedField,
  });

  factory RemoteCredentials.fromMap(Map<dynamic, dynamic> map) {
    return RemoteCredentials(
      serverUrl: map['serverUrl'] as String?,
      port: map['port'] as String?,
      username: map['username'] as String?,
      password: map['password'] as String?,
      submitted: map['submitted'] == true,
      focusedField: map['focusedField'] as String?,
    );
  }

  bool get isComplete =>
      serverUrl != null &&
      serverUrl!.isNotEmpty &&
      username != null &&
      username!.isNotEmpty &&
      password != null &&
      password!.isNotEmpty;
}

/// Service to manage keyboard sessions via Firebase Realtime Database
class KeyboardSessionService {
  static const String _sessionsPath = 'keyboard_sessions';
  // TODO: Change back to 'https://streameee.com/keyboard' for production
  static const String _baseUrl = 'https://streameee-app.web.app';

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  String? _currentSessionId;
  StreamSubscription<DatabaseEvent>? _sessionSubscription;

  /// Generate a short, readable session ID (6 chars)
  String _generateSessionId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed ambiguous chars
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Get the current session ID
  String? get currentSessionId => _currentSessionId;

  /// Get the full URL for the keyboard session
  String? get sessionUrl {
    if (_currentSessionId == null) return null;
    return '$_baseUrl/$_currentSessionId';
  }

  /// Start a new keyboard session
  /// Returns the session ID
  Future<String> startSession() async {
    // Clean up any existing session
    await endSession();

    _currentSessionId = _generateSessionId();

    // Create session in Firebase
    await _database.child('$_sessionsPath/$_currentSessionId').set({
      'createdAt': ServerValue.timestamp,
      'status': 'waiting',
      'serverUrl': '',
      'port': '80',
      'username': '',
      'password': '',
    });

    return _currentSessionId!;
  }

  /// Listen to changes in the current session
  Stream<RemoteCredentials> listenToSession() {
    if (_currentSessionId == null) {
      return const Stream.empty();
    }

    final controller = StreamController<RemoteCredentials>();

    _sessionSubscription = _database
        .child('$_sessionsPath/$_currentSessionId')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        controller.add(RemoteCredentials.fromMap(data));
      }
    });

    controller.onCancel = () {
      _sessionSubscription?.cancel();
    };

    return controller.stream;
  }

  /// Mark session as completed
  Future<void> markCompleted() async {
    if (_currentSessionId == null) return;

    await _database
        .child('$_sessionsPath/$_currentSessionId/status')
        .set('completed');
  }

  /// End the current session and clean up
  Future<void> endSession() async {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;

    if (_currentSessionId != null) {
      // Delete session from Firebase
      await _database.child('$_sessionsPath/$_currentSessionId').remove();
      _currentSessionId = null;
    }
  }

  /// Clean up old sessions (older than 1 hour)
  Future<void> cleanupOldSessions() async {
    final cutoffTime = DateTime.now().millisecondsSinceEpoch - (60 * 60 * 1000);

    final snapshot = await _database
        .child(_sessionsPath)
        .orderByChild('createdAt')
        .endAt(cutoffTime)
        .get();

    if (snapshot.exists) {
      final sessions = snapshot.value as Map<dynamic, dynamic>;
      for (final sessionId in sessions.keys) {
        await _database.child('$_sessionsPath/$sessionId').remove();
      }
    }
  }
}
