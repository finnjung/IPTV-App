import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_keyboard.dart';
import '../utils/tv_utils.dart';

/// Fullscreen TV-optimized Onboarding Wizard
/// Guides new users through initial setup: credentials + language preference
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

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

  // Connection State
  bool _isConnecting = false;
  String? _connectionError;

  // Focus Nodes
  final _nextButtonFocus = FocusNode();
  final _startButtonFocus = FocusNode();

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Language options with priority order
  static const List<(String?, String)> _languages = [
    (null, 'Keine Präferenz'),
    ('DE', 'Deutsch'),
    ('EN', 'English'),
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
    super.dispose();
  }

  void _goToNextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
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
                      _buildServerUrlStep(),
                      _buildPortStep(),
                      _buildUsernameStep(),
                      _buildPasswordStep(),
                      _buildLanguageStep(),
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
          // Logo
          Image.asset(
            'assets/images/streameee-logo.png',
            height: 80,
          ),
          const SizedBox(height: 48),
          Text(
            'Willkommen bei Streameee',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 64),
          _OnboardingButton(
            label: 'Einrichtung starten',
            onPressed: _goToNextStep,
            autofocus: true,
            focusNode: _startButtonFocus,
          ),
        ],
      ),
    );
  }

  Widget _buildServerUrlStep() {
    return _OnboardingInputStep(
      title: 'Server URL',
      description: 'Gib die URL deines IPTV-Servers ein',
      hintText: 'http://example.com',
      controller: _serverController,
      onNext: _goToNextStep,
      onBack: _goToPreviousStep,
      nextButtonFocus: _nextButtonFocus,
      isRequired: true,
    );
  }

  Widget _buildPortStep() {
    return _OnboardingInputStep(
      title: 'Port (Optional)',
      description: 'Standard ist 80. Nur ändern wenn nötig.',
      hintText: '80',
      controller: _portController,
      onNext: _goToNextStep,
      onBack: _goToPreviousStep,
      nextButtonFocus: _nextButtonFocus,
      isRequired: false,
    );
  }

  Widget _buildUsernameStep() {
    return _OnboardingInputStep(
      title: 'Benutzername',
      description: 'Dein IPTV Benutzername',
      hintText: 'username',
      controller: _usernameController,
      onNext: _goToNextStep,
      onBack: _goToPreviousStep,
      nextButtonFocus: _nextButtonFocus,
      isRequired: true,
    );
  }

  Widget _buildPasswordStep() {
    return _OnboardingInputStep(
      title: 'Passwort',
      description: 'Dein IPTV Passwort',
      hintText: 'Passwort',
      controller: _passwordController,
      onNext: _goToNextStep,
      onBack: _goToPreviousStep,
      nextButtonFocus: _nextButtonFocus,
      isPassword: true,
      isRequired: true,
    );
  }

  Widget _buildLanguageStep() {
    return _OnboardingStepLayout(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Bevorzugte Sprache',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Inhalte in dieser Sprache werden priorisiert',
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
                  onSelect: () => setState(() => _selectedLanguage = code),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 48),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OnboardingButton(
                label: 'Zurück',
                onPressed: _goToPreviousStep,
                isSecondary: true,
              ),
              const SizedBox(width: 16),
              _OnboardingButton(
                label: 'Weiter',
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
            _connectionError != null ? 'Verbindungsfehler' : 'Alles bereit!',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _connectionError ?? 'Dein IPTV ist eingerichtet',
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
                  'Verbinde...',
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
                  label: 'Zurück',
                  onPressed: _goToPreviousStep,
                  isSecondary: true,
                ),
                const SizedBox(width: 16),
                _OnboardingButton(
                  label: _connectionError != null ? 'Erneut versuchen' : 'Los geht\'s',
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

  const _OnboardingInputStep({
    required this.title,
    required this.description,
    required this.hintText,
    required this.controller,
    required this.onNext,
    required this.onBack,
    required this.nextButtonFocus,
    this.isPassword = false,
    this.isRequired = true,
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

  // Check if we should use TV keyboard (only on actual TV devices)
  bool get _useTvKeyboard {
    if (kIsWeb) return false;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return false;
    return TvUtils.useTvInterface;
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

          // Input: TextField on Desktop, TvKeyboard on TV
          if (_useTvKeyboard) ...[
            // TV: Show current value display + TvKeyboard
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
            SizedBox(
              width: 500,
              child: TvKeyboard(
                controller: widget.controller,
                hintText: widget.hintText,
                autofocus: true,
                showInputField: false,
                onSubmit: _canProceed ? _handleNext : null,
              ),
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

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OnboardingButton(
                label: 'Zurück',
                onPressed: widget.onBack,
                isSecondary: true,
              ),
              const SizedBox(width: 16),
              _OnboardingButton(
                label: widget.isRequired ? 'Weiter' : 'Überspringen',
                onPressed: _canProceed ? _handleNext : null,
                focusNode: widget.nextButtonFocus,
              ),
            ],
          ),
        ],
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
