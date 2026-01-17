import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/xtream_service.dart';
import '../services/keyboard_session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_keyboard.dart';
import '../utils/tv_utils.dart';

/// Fullscreen TV-optimized Onboarding Wizard
/// Guides new users through initial setup: credentials + language preference
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final bool forceTvMode; // For testing QR input on non-TV devices

  const OnboardingScreen({super.key, required this.onComplete, this.forceTvMode = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentStep = 0;
  static const int _totalSteps = 7;

  // Input Controllers
  final _serverController = TextEditingController();
  final _portController = TextEditingController(text: '80');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedLanguage;

  // Localization - null means not selected yet (show English)
  String? _uiLanguage;

  // Localized strings
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'welcome': 'Welcome to streameee',
      'start_setup': 'Start Setup',
      'choose_language': 'Choose Your Language',
      'language_hint': 'Content in your preferred language will be prioritized',
      'server_url': 'Server URL',
      'server_url_desc': 'Enter your IPTV server URL',
      'port': 'Port (Optional)',
      'port_desc': 'Default is 80. Only change if needed.',
      'username': 'Username',
      'username_desc': 'Your IPTV username',
      'password': 'Password',
      'password_desc': 'Your IPTV password',
      'back': 'Back',
      'next': 'Next',
      'skip': 'Skip',
      'close': 'Close',
      'lets_go': 'Let\'s Go',
      'retry': 'Retry',
      'all_set': 'You\'re All Set!',
      'connecting': 'Connecting to server...',
      'connection_failed': 'Connection failed. Please check your details.',
      'how_to_enter': 'How do you want to enter?',
      'remote': 'Remote',
      'remote_desc': 'TV keyboard',
      'smartphone': 'Smartphone',
      'smartphone_desc': 'Scan QR code',
      'show_keyboard': 'Show Keyboard',
      'hide_keyboard': 'Hide Keyboard',
      'other_method': 'Other Method',
      'scan_qr': 'Scan the QR code with your phone\nto enter all credentials',
      'waiting_input': 'Waiting for input...',
      'recommended': 'Recommended',
      'no_preference': 'No Preference',
    },
    'de': {
      'welcome': 'Willkommen bei streameee',
      'start_setup': 'Einrichtung starten',
      'choose_language': 'Wähle deine Sprache',
      'language_hint': 'Inhalte in deiner bevorzugten Sprache werden priorisiert',
      'server_url': 'Server URL',
      'server_url_desc': 'Gib die URL deines IPTV-Servers ein',
      'port': 'Port (Optional)',
      'port_desc': 'Standard ist 80. Nur ändern wenn nötig.',
      'username': 'Benutzername',
      'username_desc': 'Dein IPTV Benutzername',
      'password': 'Passwort',
      'password_desc': 'Dein IPTV Passwort',
      'back': 'Zurück',
      'next': 'Weiter',
      'skip': 'Überspringen',
      'close': 'Schließen',
      'lets_go': 'Los geht\'s',
      'retry': 'Erneut versuchen',
      'all_set': 'Alles bereit!',
      'connecting': 'Verbinde mit Server...',
      'connection_failed': 'Verbindung fehlgeschlagen. Bitte prüfe deine Eingaben.',
      'how_to_enter': 'Wie möchtest du eingeben?',
      'remote': 'Fernbedienung',
      'remote_desc': 'Tastatur auf dem TV',
      'smartphone': 'Smartphone',
      'smartphone_desc': 'QR-Code scannen',
      'show_keyboard': 'Tastatur einblenden',
      'hide_keyboard': 'Tastatur ausblenden',
      'other_method': 'Andere Methode',
      'scan_qr': 'Scanne den QR-Code mit deinem Handy\num alle Zugangsdaten einzugeben',
      'waiting_input': 'Warte auf Eingabe...',
      'recommended': 'Empfohlen',
      'no_preference': 'Keine Präferenz',
    },
  };

  String _t(String key) {
    final lang = _uiLanguage ?? 'en';
    return _strings[lang]?[key] ?? _strings['en']![key]!;
  }

  // Connection State
  bool _isConnecting = false;
  String? _connectionError;

  // Focus Nodes
  final _nextButtonFocus = FocusNode();
  final _startButtonFocus = FocusNode();

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // QR Code / Remote Keyboard
  final KeyboardSessionService _keyboardSessionService = KeyboardSessionService();
  StreamSubscription<RemoteCredentials>? _credentialsSubscription;
  bool _isQrSessionActive = false;

  // Input method state (persisted across steps)
  _TvInputMethod _inputMethod = _TvInputMethod.none;
  bool _showKeyboard = false;

  // Track previous credentials for detecting field changes
  String _prevServerUrl = '';
  String _prevPort = '80';
  String _prevUsername = '';
  String _prevPassword = '';

  // Debounce timer for syncing TV input to Firebase
  Timer? _tvSyncDebounce;

  // Language options with priority order
  static const List<(String?, String)> _languages = [
    (null, 'English'),
    ('DE', 'Deutsch'),
    ('TR', 'Türkçe'),
    ('FR', 'Français'),
    ('ES', 'Español'),
    ('IT', 'Italiano'),
    ('AR', 'العربية'),
    ('RU', 'Русский'),
    ('PL', 'Polski'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _nextButtonFocus.dispose();
    _startButtonFocus.dispose();
    _fadeController.dispose();
    _credentialsSubscription?.cancel();
    _tvSyncDebounce?.cancel();
    _keyboardSessionService.endSession();
    super.dispose();
  }

  /// Sync TV keyboard input to Firebase (for bidirectional sync)
  void _syncTvInputToFirebase() {
    if (!_isQrSessionActive) return;

    _tvSyncDebounce?.cancel();
    _tvSyncDebounce = Timer(const Duration(milliseconds: 300), () {
      _keyboardSessionService.updateFromTv(
        serverUrl: _serverController.text,
        port: _portController.text.isEmpty ? '80' : _portController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
    });
  }

  /// Start QR code session for remote keyboard input
  Future<void> _startQrSession() async {
    await _keyboardSessionService.startSession();

    // Add listeners to sync TV keyboard input to phone
    _serverController.addListener(_syncTvInputToFirebase);
    _portController.addListener(_syncTvInputToFirebase);
    _usernameController.addListener(_syncTvInputToFirebase);
    _passwordController.addListener(_syncTvInputToFirebase);

    setState(() {
      _isQrSessionActive = true;
      _inputMethod = _TvInputMethod.qrCode;
    });

    _credentialsSubscription = _keyboardSessionService.listenToSession().listen(
      (credentials) {
        setState(() {
          final newServerUrl = credentials.serverUrl ?? '';
          final newPort = credentials.port ?? '80';
          final newUsername = credentials.username ?? '';
          final newPassword = credentials.password ?? '';

          // Only update text controllers if the change came from phone (not TV)
          // This prevents overwriting what the user is typing on TV
          if (credentials.source != 'tv') {
            if (newServerUrl.isNotEmpty && _serverController.text != newServerUrl) {
              _serverController.text = newServerUrl;
            }
            if (newPort.isNotEmpty && _portController.text != newPort) {
              _portController.text = newPort;
            }
            if (newUsername.isNotEmpty && _usernameController.text != newUsername) {
              _usernameController.text = newUsername;
            }
            if (newPassword.isNotEmpty && _passwordController.text != newPassword) {
              _passwordController.text = newPassword;
            }
          }

          // Detect which field is focused or being edited and jump to that step
          // Steps: 2=serverUrl, 3=port, 4=username, 5=password
          int? targetStep;

          // First priority: focused field (user tapped on a field)
          final focusedField = credentials.focusedField;
          if (focusedField != null) {
            switch (focusedField) {
              case 'serverUrl':
                targetStep = 2;
                break;
              case 'port':
                targetStep = 3;
                break;
              case 'username':
                targetStep = 4;
                break;
              case 'password':
                targetStep = 5;
                break;
            }
          }

          // Second priority: detect field changes (fallback)
          if (targetStep == null) {
            if (newPassword != _prevPassword && newPassword.isNotEmpty) {
              targetStep = 5; // Password step
            } else if (newUsername != _prevUsername && newUsername.isNotEmpty) {
              targetStep = 4; // Username step
            } else if (newPort != _prevPort && newPort != '80') {
              targetStep = 3; // Port step
            } else if (newServerUrl != _prevServerUrl && newServerUrl.isNotEmpty) {
              targetStep = 2; // Server URL step
            }
          }

          // Navigate to the field being edited (only if we're on a credential step)
          if (targetStep != null && _currentStep >= 2 && _currentStep <= 5 && _currentStep != targetStep) {
            _currentStep = targetStep;
            _pageController.animateToPage(
              targetStep,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }

          // Update previous values
          _prevServerUrl = newServerUrl;
          _prevPort = newPort;
          _prevUsername = newUsername;
          _prevPassword = newPassword;

          // Only proceed when user explicitly submitted (clicked "Send to TV")
          if (credentials.submitted && credentials.isComplete) {
            _keyboardSessionService.markCompleted();
            _isQrSessionActive = false;
            // Go to success step and auto-start connection test
            _currentStep = 6;
            _pageController.jumpToPage(6);
            // Start connection test automatically
            Future.delayed(const Duration(milliseconds: 300), () {
              _completeOnboarding();
            });
          }
        });
      },
    );
  }

  /// Stop QR code session
  Future<void> _stopQrSession() async {
    // Remove TV sync listeners
    _serverController.removeListener(_syncTvInputToFirebase);
    _portController.removeListener(_syncTvInputToFirebase);
    _usernameController.removeListener(_syncTvInputToFirebase);
    _passwordController.removeListener(_syncTvInputToFirebase);
    _tvSyncDebounce?.cancel();

    _credentialsSubscription?.cancel();
    _credentialsSubscription = null;
    await _keyboardSessionService.endSession();
    setState(() => _isQrSessionActive = false);
  }

  void _goToNextStep() {
    if (_currentStep < _totalSteps - 1) {
      final nextStep = _currentStep + 1;
      setState(() => _currentStep = nextStep);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      // Auto-start connection test when reaching success step
      if (nextStep == 6) {
        Future.delayed(const Duration(milliseconds: 450), () {
          _completeOnboarding();
        });
      }
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _connectionError = null;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      final credentials = XtreamCredentials(
        serverUrl: _serverController.text.trim(),
        port: _portController.text.trim().isEmpty
            ? '80'
            : _portController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      final xtreamService = context.read<XtreamService>();
      final success = await xtreamService.connect(credentials);

      if (success) {
        // Save onboarding completed flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);

        // Save language preference if selected
        if (_selectedLanguage != null) {
          await prefs.setString('preferred_language', _selectedLanguage!);
          xtreamService.setPreferredLanguage(_selectedLanguage!);
        }

        widget.onComplete();
      } else {
        setState(() {
          _connectionError = 'Verbindung fehlgeschlagen. Bitte prüfe deine Eingaben.';
          _isConnecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _connectionError = 'Fehler: ${e.toString()}';
        _isConnecting = false;
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Back button goes to previous step (except on welcome)
      if ((event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.gameButtonB) &&
          _currentStep > 0) {
        _goToPreviousStep();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Focus(
        onKeyEvent: _handleKeyEvent,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Step indicator
                Padding(
                  padding: const EdgeInsets.only(top: 32, bottom: 16),
                  child: _StepIndicator(
                    currentStep: _currentStep,
                    totalSteps: _totalSteps,
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildWelcomeStep(),
                      _buildLanguageStep(),  // Language first!
                      _buildServerUrlStep(),
                      _buildPortStep(),
                      _buildUsernameStep(),
                      _buildPasswordStep(),
                      _buildSuccessStep(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return _OnboardingStepLayout(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Welcome to streameee
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Welcome to ',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withAlpha(180),
                ),
              ),
              Text(
                'streameee',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
          _OnboardingButton(
            label: 'Start Setup',
            onPressed: _goToNextStep,
            autofocus: true,
            focusNode: _startButtonFocus,
          ),
        ],
      ),
    );
  }

  // Get session URL with language parameter
  String? get _sessionUrlWithLang {
    final baseUrl = _keyboardSessionService.sessionUrl;
    if (baseUrl == null) return null;
    final lang = _uiLanguage ?? 'en';
    return '$baseUrl?lang=$lang';
  }

  Widget _buildServerUrlStep() {
    return _OnboardingInputStep(
      title: _t('server_url'),
      description: _t('server_url_desc'),
      hintText: 'http://example.com',
      controller: _serverController,
      onNext: _goToNextStep,
      onBack: _goToPreviousStep,
      nextButtonFocus: _nextButtonFocus,
      isRequired: true,
      onStartQrSession: _startQrSession,
      onStopQrSession: _stopQrSession,
      qrSessionUrl: _sessionUrlWithLang,
      isQrSessionActive: _isQrSessionActive,
      forceTvMode: widget.forceTvMode,
      strings: _strings[_uiLanguage ?? 'en']!,
      inputMethod: _inputMethod,
      showKeyboard: _showKeyboard,
      onInputMethodChanged: (method) => setState(() => _inputMethod = method),
      onShowKeyboardChanged: (show) => setState(() => _showKeyboard = show),
    );
  }

  Widget _buildPortStep() {
    return _OnboardingInputStep(
      title: _t('port'),
      description: _t('port_desc'),
      hintText: '80',
      controller: _portController,
      onNext: _goToNextStep,
      onBack: _goToPreviousStep,
      nextButtonFocus: _nextButtonFocus,
      isRequired: false,
      onStartQrSession: _startQrSession,
      onStopQrSession: _stopQrSession,
      qrSessionUrl: _sessionUrlWithLang,
      isQrSessionActive: _isQrSessionActive,
      forceTvMode: widget.forceTvMode,
      strings: _strings[_uiLanguage ?? 'en']!,
      inputMethod: _inputMethod,
      showKeyboard: _showKeyboard,
      onInputMethodChanged: (method) => setState(() => _inputMethod = method),
      onShowKeyboardChanged: (show) => setState(() => _showKeyboard = show),
    );
  }

  Widget _buildUsernameStep() {
    return _OnboardingInputStep(
      title: _t('username'),
      description: _t('username_desc'),
      hintText: 'username',
      controller: _usernameController,
      onNext: _goToNextStep,
      onBack: _goToPreviousStep,
      nextButtonFocus: _nextButtonFocus,
      isRequired: true,
      onStartQrSession: _startQrSession,
      onStopQrSession: _stopQrSession,
      qrSessionUrl: _sessionUrlWithLang,
      isQrSessionActive: _isQrSessionActive,
      forceTvMode: widget.forceTvMode,
      strings: _strings[_uiLanguage ?? 'en']!,
      inputMethod: _inputMethod,
      showKeyboard: _showKeyboard,
      onInputMethodChanged: (method) => setState(() => _inputMethod = method),
      onShowKeyboardChanged: (show) => setState(() => _showKeyboard = show),
    );
  }

  Widget _buildPasswordStep() {
    return _OnboardingInputStep(
      title: _t('password'),
      description: _t('password_desc'),
      hintText: _t('password'),
      controller: _passwordController,
      onNext: _goToNextStep,
      onBack: _goToPreviousStep,
      nextButtonFocus: _nextButtonFocus,
      isPassword: true,
      isRequired: true,
      onStartQrSession: _startQrSession,
      onStopQrSession: _stopQrSession,
      qrSessionUrl: _sessionUrlWithLang,
      isQrSessionActive: _isQrSessionActive,
      forceTvMode: widget.forceTvMode,
      strings: _strings[_uiLanguage ?? 'en']!,
      inputMethod: _inputMethod,
      showKeyboard: _showKeyboard,
      onInputMethodChanged: (method) => setState(() => _inputMethod = method),
      onShowKeyboardChanged: (show) => setState(() => _showKeyboard = show),
    );
  }

  void _selectLanguage(String? code) {
    setState(() {
      _selectedLanguage = code;
      // Set UI language based on selection (only EN/DE supported for now)
      if (code == 'DE') {
        _uiLanguage = 'de';
      } else {
        _uiLanguage = 'en'; // Default to English for all other languages
      }
    });
  }

  Widget _buildLanguageStep() {
    // This step is shown in English first, then switches after selection
    return _OnboardingStepLayout(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Choose Your Language',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Content in your preferred language will be prioritized',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 40),

          // Language Grid
          SizedBox(
            width: 600,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: _languages.map((lang) {
                final (code, name) = lang;
                final isSelected = _selectedLanguage == code;
                return _LanguageChip(
                  code: code,
                  name: name,
                  isSelected: isSelected,
                  onSelect: () => _selectLanguage(code),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 48),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OnboardingButton(
                label: 'Back',
                onPressed: _goToPreviousStep,
                isSecondary: true,
              ),
              const SizedBox(width: 16),
              _OnboardingButton(
                label: 'Next',
                onPressed: _goToNextStep,
                autofocus: true,
                focusNode: _nextButtonFocus,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    final successMessage = _uiLanguage == 'de' ? 'Dein IPTV ist eingerichtet' : 'Your IPTV is set up';
    final errorTitle = _uiLanguage == 'de' ? 'Verbindungsfehler' : 'Connection Error';

    return _OnboardingStepLayout(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _connectionError != null ? Icons.error_outline : Icons.check_circle_outline,
              size: 60,
              color: _connectionError != null ? Colors.red : Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _connectionError != null ? errorTitle : _t('all_set'),
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _connectionError ?? successMessage,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: _connectionError != null
                  ? Colors.red.shade300
                  : Colors.white.withAlpha(150),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          if (_isConnecting)
            Column(
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  _t('connecting'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withAlpha(150),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OnboardingButton(
                  label: _t('back'),
                  onPressed: _goToPreviousStep,
                  isSecondary: true,
                ),
                const SizedBox(width: 16),
                _OnboardingButton(
                  label: _connectionError != null ? _t('retry') : _t('lets_go'),
                  onPressed: _completeOnboarding,
                  autofocus: true,
                  focusNode: _nextButtonFocus,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Layout wrapper for onboarding steps
class _OnboardingStepLayout extends StatelessWidget {
  final Widget child;

  const _OnboardingStepLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: child,
      ),
    );
  }
}

/// Input method enum for TV
enum _TvInputMethod { none, remote, qrCode }

/// Step with text input using TvKeyboard
class _OnboardingInputStep extends StatefulWidget {
  final String title;
  final String description;
  final String hintText;
  final TextEditingController controller;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final FocusNode nextButtonFocus;
  final bool isPassword;
  final bool isRequired; // If true, input must not be empty

  // QR Code session callbacks
  final Future<void> Function()? onStartQrSession;
  final Future<void> Function()? onStopQrSession;
  final String? qrSessionUrl;
  final bool isQrSessionActive;
  final bool forceTvMode;

  // Input method state (from parent)
  final _TvInputMethod inputMethod;
  final bool showKeyboard;
  final ValueChanged<_TvInputMethod> onInputMethodChanged;
  final ValueChanged<bool> onShowKeyboardChanged;

  // Localized strings
  final Map<String, String> strings;

  const _OnboardingInputStep({
    required this.title,
    required this.description,
    required this.hintText,
    required this.controller,
    required this.onNext,
    required this.onBack,
    required this.nextButtonFocus,
    required this.strings,
    required this.inputMethod,
    required this.showKeyboard,
    required this.onInputMethodChanged,
    required this.onShowKeyboardChanged,
    this.isPassword = false,
    this.isRequired = true,
    this.onStartQrSession,
    this.onStopQrSession,
    this.qrSessionUrl,
    this.isQrSessionActive = false,
    this.forceTvMode = false,
  });

  @override
  State<_OnboardingInputStep> createState() => _OnboardingInputStepState();
}

class _OnboardingInputStepState extends State<_OnboardingInputStep> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  bool get _canProceed {
    if (!widget.isRequired) return true;
    return widget.controller.text.trim().isNotEmpty;
  }

  void _handleNext() {
    if (_canProceed) {
      widget.onNext();
    }
  }

  // Check if we should use TV keyboard (only on actual TV devices, or forced)
  bool get _useTvKeyboard {
    if (widget.forceTvMode) return true;
    if (kIsWeb) return false;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return false;
    return TvUtils.useTvInterface;
  }

  // Convenience getters/setters for input method state
  _TvInputMethod get _selectedMethod => widget.inputMethod;
  bool get _showKeyboard => widget.showKeyboard;

  void _setSelectedMethod(_TvInputMethod method) {
    widget.onInputMethodChanged(method);
  }

  void _setShowKeyboard(bool show) {
    widget.onShowKeyboardChanged(show);
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingStepLayout(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withAlpha(150),
            ),
          ),
          const SizedBox(height: 32),

          // Input: TextField on Desktop, Method selection on TV
          if (_useTvKeyboard) ...[
            // TV: Show current value display
            Container(
              width: 500,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: Text(
                widget.isPassword
                    ? '*' * widget.controller.text.length
                    : (widget.controller.text.isEmpty
                        ? widget.hintText
                        : widget.controller.text),
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: widget.controller.text.isEmpty
                      ? Colors.white.withAlpha(80)
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Input method selection with animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _selectedMethod == _TvInputMethod.none
                  ? _buildInputMethodSelection()
                  : _selectedMethod == _TvInputMethod.remote
                      ? _buildRemoteInputSection()
                      : _buildQrCodeSection(),
            ),
          ] else ...[
            // Desktop: Use native TextField
            SizedBox(
              width: 500,
              child: TextField(
                controller: widget.controller,
                obscureText: widget.isPassword,
                autofocus: true,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 20,
                    color: Colors.white.withAlpha(80),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onSubmitted: (_) => _handleNext(),
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Navigation buttons (hide when keyboard is showing - buttons are beside keyboard then)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: (_selectedMethod == _TvInputMethod.remote && _showKeyboard)
                ? const SizedBox.shrink(key: ValueKey('no_buttons'))
                : Row(
                    key: const ValueKey('nav_buttons'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _OnboardingButton(
                        label: widget.strings['back']!,
                        onPressed: widget.onBack,
                        isSecondary: true,
                      ),
                      const SizedBox(width: 16),
                      _OnboardingButton(
                        label: widget.isRequired ? widget.strings['next']! : widget.strings['skip']!,
                        onPressed: _canProceed ? _handleNext : null,
                        focusNode: widget.nextButtonFocus,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputMethodSelection() {
    return Column(
      key: const ValueKey('input_method_selection'),
      children: [
        Text(
          widget.strings['how_to_enter']!,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white.withAlpha(180),
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InputMethodCard(
                icon: Icons.keyboard,
                label: widget.strings['remote']!,
                description: widget.strings['remote_desc']!,
                onTap: () {
                  _setSelectedMethod(_TvInputMethod.remote);
                  _setShowKeyboard(true); // Open keyboard directly
                },
                autofocus: true,
              ),
              const SizedBox(width: 16),
              _InputMethodCard(
                icon: Icons.qr_code,
                label: widget.strings['smartphone']!,
                description: widget.strings['smartphone_desc']!,
                showRecommendedBadge: true,
                recommendedLabel: widget.strings['recommended']!,
                onTap: () {
                  widget.onStartQrSession?.call();
                  _setSelectedMethod(_TvInputMethod.qrCode);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteInputSection() {
    // Keyboard with navigation buttons beside it
    return Row(
      key: const ValueKey('remote_keyboard'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Keyboard
        TvKeyboard(
          controller: widget.controller,
          hintText: widget.hintText,
          autofocus: true,
          showInputField: false,
          onClose: () {
            _setSelectedMethod(_TvInputMethod.none);
            _setShowKeyboard(false);
          },
          onSubmit: _canProceed ? _handleNext : null,
        ),

        const SizedBox(width: 24),

        // Navigation buttons column
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close keyboard button
              _OnboardingButton(
                label: widget.strings['close'] ?? 'Close',
                onPressed: () {
                  _setSelectedMethod(_TvInputMethod.none);
                  _setShowKeyboard(false);
                },
                isSecondary: true,
              ),
              const SizedBox(height: 12),
              _OnboardingButton(
                label: widget.strings['back']!,
                onPressed: widget.onBack,
                isSecondary: true,
              ),
              const SizedBox(height: 12),
              _OnboardingButton(
                label: widget.isRequired ? widget.strings['next']! : widget.strings['skip']!,
                onPressed: _canProceed ? _handleNext : null,
                focusNode: widget.nextButtonFocus,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeSection() {
    final sessionUrl = widget.qrSessionUrl;

    return Row(
      key: const ValueKey('qr_code_section'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left side: QR Code
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: sessionUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: QrImageView(
                        data: sessionUrl,
                        version: QrVersions.auto,
                        size: 160,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    )
                  : Center(
                      child: CircularProgressIndicator(
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),
            if (sessionUrl != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sessionUrl.replaceAll('https://', '').split('?').first,
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    color: Colors.white.withAlpha(150),
                  ),
                ),
              ),
            ],
          ],
        ),

        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            width: 1,
            height: 140,
            color: Colors.white.withAlpha(30),
          ),
        ),

        // Right side: Info & Button
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.strings['scan_qr']!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withAlpha(180),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sync,
                  size: 14,
                  color: Colors.green.shade400,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.strings['waiting_input']!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.green.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _OnboardingButton(
              label: widget.strings['other_method']!,
              onPressed: () {
                widget.onStopQrSession?.call();
                _setSelectedMethod(_TvInputMethod.none);
              },
              isSecondary: true,
              autofocus: true,
            ),
          ],
        ),
      ],
    );
  }
}

/// Card for selecting input method on TV
class _InputMethodCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool autofocus;
  final bool showRecommendedBadge;
  final String recommendedLabel;

  const _InputMethodCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.autofocus = false,
    this.showRecommendedBadge = false,
    this.recommendedLabel = 'Recommended',
  });

  @override
  State<_InputMethodCard> createState() => _InputMethodCardState();
}

class _InputMethodCardState extends State<_InputMethodCard> {
  bool _isFocused = false;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: _isFocused ? AppTheme.accentColor : AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: _isFocused
                    ? Border.all(color: Colors.white, width: 3)
                    : Border.all(color: Colors.white.withAlpha(30)),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: AppTheme.accentColor.withAlpha(100),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withAlpha(150),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Recommended badge
            if (widget.showRecommendedBadge)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withAlpha(100),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    widget.recommendedLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// TV-optimized button for onboarding
class _OnboardingButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool isSecondary;

  const _OnboardingButton({
    required this.label,
    required this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.isSecondary = false,
  });

  @override
  State<_OnboardingButton> createState() => _OnboardingButtonState();
}

class _OnboardingButtonState extends State<_OnboardingButton> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onPressed?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    final bgColor = widget.isSecondary
        ? AppTheme.surfaceDark
        : (isDisabled ? AppTheme.surfaceDark : AppTheme.accentColor);
    final focusBgColor = widget.isSecondary
        ? AppTheme.cardDark
        : AppTheme.accentColor;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: _isFocused ? focusBgColor : bgColor,
            borderRadius: BorderRadius.circular(12),
            border: _isFocused
                ? Border.all(color: Colors.white, width: 3)
                : null,
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: focusBgColor.withAlpha(100),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: _isFocused ? FontWeight.bold : FontWeight.w600,
              color: isDisabled
                  ? Colors.white.withAlpha(80)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Language selection chip
class _LanguageChip extends StatefulWidget {
  final String? code;
  final String name;
  final bool isSelected;
  final VoidCallback onSelect;

  const _LanguageChip({
    required this.code,
    required this.name,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<_LanguageChip> createState() => _LanguageChipState();
}

class _LanguageChipState extends State<_LanguageChip> {
  bool _isFocused = false;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onSelect();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final showHighlight = _isFocused || widget.isSelected;

    return Focus(
      autofocus: widget.code == null, // Focus "Keine Präferenz" by default
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: showHighlight
                ? AppTheme.accentColor.withAlpha(widget.isSelected ? 255 : 80)
                : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(24),
            border: _isFocused
                ? Border.all(color: Colors.white, width: 2)
                : (widget.isSelected
                    ? Border.all(color: AppTheme.accentColor, width: 2)
                    : null),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.accentColor.withAlpha(60),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSelected) ...[
                const Icon(Icons.check, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.name,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: showHighlight ? FontWeight.w600 : FontWeight.normal,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step indicator dots
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isPast = index < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : (isPast ? Colors.white.withAlpha(150) : Colors.white.withAlpha(50)),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
