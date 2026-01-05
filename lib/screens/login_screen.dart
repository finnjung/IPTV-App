import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/xtream_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _corsProxyController = TextEditingController(
    text: 'https://corsproxy.io/?',
  );

  bool _obscurePassword = true;
  bool _isConnecting = false;
  bool _useCorsProxy = false;

  @override
  void dispose() {
    _serverController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _corsProxyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isConnecting = true);

    final xtreamService = context.read<XtreamService>();

    final credentials = XtreamCredentials(
      serverUrl: _serverController.text.trim(),
      port: _portController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      corsProxy: _useCorsProxy ? _corsProxyController.text.trim() : null,
    );

    final success = await xtreamService.connect(credentials);

    setState(() => _isConnecting = false);

    if (success && mounted) {
      widget.onLoginSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/television.svg',
                          width: 48,
                          height: 48,
                          colorFilter: ColorFilter.mode(
                            colorScheme.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'IPTV verbinden',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gib deine Xtream Codes Zugangsdaten ein',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: colorScheme.onSurface.withAlpha(150),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Error Message
                if (xtreamService.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.error.withAlpha(50),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            xtreamService.error!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => xtreamService.clearError(),
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Server URL
                      _buildLabel('Server URL'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _serverController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'http://example.com',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              'assets/icons/globe.svg',
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                colorScheme.onSurface.withAlpha(100),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte Server URL eingeben';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Port
                      _buildLabel('Port (optional)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Leer lassen wenn nicht benötigt',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              'assets/icons/hash.svg',
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                colorScheme.onSurface.withAlpha(100),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Username
                      _buildLabel('Benutzername'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: 'Dein Benutzername',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              'assets/icons/user.svg',
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                colorScheme.onSurface.withAlpha(100),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte Benutzername eingeben';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Password
                      _buildLabel('Passwort'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Dein Passwort',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              'assets/icons/lock.svg',
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                colorScheme.onSurface.withAlpha(100),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                            icon: SvgPicture.asset(
                              _obscurePassword
                                  ? 'assets/icons/eye.svg'
                                  : 'assets/icons/eye-slash.svg',
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                colorScheme.onSurface.withAlpha(100),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte Passwort eingeben';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // CORS Proxy Toggle (for Web)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withAlpha(25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Web-Modus (CORS Proxy)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Aktivieren wenn du im Browser testest',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: colorScheme.onSurface.withAlpha(120),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _useCorsProxy,
                                  onChanged: (value) {
                                    setState(() => _useCorsProxy = value);
                                  },
                                  activeTrackColor: colorScheme.primary.withAlpha(150),
                                  activeThumbColor: colorScheme.primary,
                                ),
                              ],
                            ),
                            if (_useCorsProxy) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _corsProxyController,
                                decoration: InputDecoration(
                                  hintText: 'https://corsproxy.io/?',
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SvgPicture.asset(
                                      'assets/icons/link.svg',
                                      width: 20,
                                      height: 20,
                                      colorFilter: ColorFilter.mode(
                                        colorScheme.onSurface.withAlpha(100),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Connect Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isConnecting ? null : _connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            disabledBackgroundColor:
                                colorScheme.primary.withAlpha(150),
                          ),
                          child: _isConnecting
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white.withAlpha(200),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icons/plug.svg',
                                      width: 20,
                                      height: 20,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Verbinden',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withAlpha(25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/info.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Die Zugangsdaten erhältst du von deinem IPTV-Anbieter. '
                          'Sie werden sicher auf deinem Gerät gespeichert.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: colorScheme.onSurface.withAlpha(150),
                            height: 1.4,
                          ),
                        ),
                      ),
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

  Widget _buildLabel(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
    );
  }
}
