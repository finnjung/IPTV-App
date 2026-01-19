import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Information about an available update
class UpdateInfo {
  final String version;
  final int versionCode;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;

  UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.apkUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      versionCode: json['versionCode'] as int? ?? 1,
      apkUrl: json['apkUrl'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }
}

/// State of the update process
enum UpdateState {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  installing,
  error,
}

/// Service for checking and installing app updates on Fire TV
class AppUpdateService extends ChangeNotifier {
  static const _channel = MethodChannel('com.streameee.app/app_update');
  static const _manifestUrl = 'https://streameee.com/update/manifest.json';

  UpdateState _state = UpdateState.idle;
  UpdateInfo? _updateInfo;
  double _downloadProgress = 0.0;
  String? _downloadedFilePath;
  String? _errorMessage;

  UpdateState get state => _state;
  UpdateInfo? get updateInfo => _updateInfo;
  double get downloadProgress => _downloadProgress;
  String? get downloadedFilePath => _downloadedFilePath;
  String? get errorMessage => _errorMessage;

  bool get hasUpdate => _updateInfo != null;
  bool get isDownloading => _state == UpdateState.downloading;
  bool get isReadyToInstall => _state == UpdateState.readyToInstall;

  AppUpdateService() {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDownloadProgress':
          _downloadProgress = (call.arguments as num).toDouble();
          notifyListeners();
          break;
        case 'onDownloadComplete':
          _downloadedFilePath = call.arguments as String;
          _state = UpdateState.readyToInstall;
          _downloadProgress = 1.0;
          notifyListeners();
          break;
        case 'onDownloadFailed':
          _errorMessage = call.arguments as String;
          _state = UpdateState.error;
          notifyListeners();
          break;
      }
    });
  }

  /// Get the current app version code
  Future<int> _getVersionCode() async {
    if (kIsWeb || !Platform.isAndroid) {
      return 0;
    }
    try {
      final result = await _channel.invokeMethod<int>('getVersionCode');
      return result ?? 0;
    } catch (e) {
      debugPrint('Error getting version code: $e');
      return 0;
    }
  }

  /// Get the current app version name (e.g., "1.0.0")
  Future<String> getVersionName() async {
    if (kIsWeb || !Platform.isAndroid) {
      return '1.0.0';
    }
    try {
      final result = await _channel.invokeMethod<String>('getVersionName');
      return result ?? '1.0.0';
    } catch (e) {
      debugPrint('Error getting version name: $e');
      return '1.0.0';
    }
  }

  /// Check for available updates
  /// Returns UpdateInfo if an update is available, null otherwise
  Future<UpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    _state = UpdateState.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch manifest from server
      final response = await http.get(Uri.parse(_manifestUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to fetch update manifest: ${response.statusCode}');
        _state = UpdateState.idle;
        notifyListeners();
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final serverInfo = UpdateInfo.fromJson(json);

      // Get current version code
      final currentVersionCode = await _getVersionCode();
      debugPrint(
          'Update check: current=$currentVersionCode, server=${serverInfo.versionCode}');

      // Compare versions
      if (serverInfo.versionCode > currentVersionCode) {
        _updateInfo = serverInfo;
        _state = UpdateState.available;
        notifyListeners();
        return serverInfo;
      }

      _state = UpdateState.idle;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Error checking for update: $e');
      _state = UpdateState.idle;
      notifyListeners();
      return null;
    }
  }

  /// Start downloading the update
  Future<bool> downloadUpdate() async {
    if (_updateInfo == null || kIsWeb || !Platform.isAndroid) {
      return false;
    }

    _state = UpdateState.downloading;
    _downloadProgress = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      // Extract filename from URL
      final uri = Uri.parse(_updateInfo!.apkUrl);
      final fileName = uri.pathSegments.last;

      await _channel.invokeMethod('downloadApk', {
        'url': _updateInfo!.apkUrl,
        'fileName': fileName,
      });

      return true;
    } catch (e) {
      debugPrint('Error starting download: $e');
      _errorMessage = e.toString();
      _state = UpdateState.error;
      notifyListeners();
      return false;
    }
  }

  /// Install the downloaded update
  Future<bool> installUpdate() async {
    if (_downloadedFilePath == null || kIsWeb || !Platform.isAndroid) {
      return false;
    }

    _state = UpdateState.installing;
    notifyListeners();

    try {
      await _channel.invokeMethod('installApk', {
        'filePath': _downloadedFilePath,
      });
      return true;
    } catch (e) {
      debugPrint('Error installing update: $e');
      _errorMessage = e.toString();
      _state = UpdateState.error;
      notifyListeners();
      return false;
    }
  }

  /// Cancel the current download
  Future<void> cancelDownload() async {
    if (!isDownloading) return;

    try {
      await _channel.invokeMethod('cancelDownload');
      _state = UpdateState.available;
      _downloadProgress = 0.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error canceling download: $e');
    }
  }

  /// Reset the update state
  void reset() {
    _state = UpdateState.idle;
    _updateInfo = null;
    _downloadProgress = 0.0;
    _downloadedFilePath = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Dismiss the update (user chose "Later")
  void dismissUpdate() {
    _state = UpdateState.idle;
    notifyListeners();
  }
}
