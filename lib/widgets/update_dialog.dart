import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// TV-optimized dialog for app updates
class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  /// Show the update dialog
  static Future<void> show(BuildContext context, UpdateInfo updateInfo) async {
    return showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (context) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final FocusNode _updateButtonFocus = FocusNode();
  final FocusNode _laterButtonFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the update button
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateButtonFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _updateButtonFocus.dispose();
    _laterButtonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppUpdateService>(
      builder: (context, updateService, _) {
        return PopScope(
          canPop: !widget.updateInfo.forceUpdate && !updateService.isDownloading,
          child: Dialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.system_update,
                          color: AppTheme.primaryColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Update verfügbar',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Version ${widget.updateInfo.version}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Release Notes
                  if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
                    const Text(
                      'Neuerungen:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.updateInfo.releaseNotes,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Download Progress
                  if (updateService.isDownloading) ...[
                    _buildProgressSection(updateService),
                    const SizedBox(height: 24),
                  ],

                  // Error Message
                  if (updateService.state == UpdateState.error &&
                      updateService.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Fehler: ${updateService.errorMessage}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Buttons
                  _buildButtons(context, updateService),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressSection(AppUpdateService updateService) {
    final progress = updateService.downloadProgress;
    final percentage = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Download läuft...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context, AppUpdateService updateService) {
    // Show different buttons based on state
    if (updateService.isDownloading) {
      return _buildCancelButton(context, updateService);
    }

    if (updateService.isReadyToInstall) {
      return _buildInstallButton(context, updateService);
    }

    return _buildUpdateButtons(context, updateService);
  }

  Widget _buildUpdateButtons(
      BuildContext context, AppUpdateService updateService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Later button (only if not force update)
        if (!widget.updateInfo.forceUpdate) ...[
          _DialogButton(
            focusNode: _laterButtonFocus,
            onPressed: () {
              updateService.dismissUpdate();
              Navigator.of(context).pop();
            },
            isPrimary: false,
            child: const Text('Später'),
          ),
          const SizedBox(width: 16),
        ],

        // Update button
        _DialogButton(
          focusNode: _updateButtonFocus,
          onPressed: () => updateService.downloadUpdate(),
          isPrimary: true,
          autofocus: true,
          child: const Text('Jetzt aktualisieren'),
        ),
      ],
    );
  }

  Widget _buildCancelButton(
      BuildContext context, AppUpdateService updateService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _DialogButton(
          focusNode: _laterButtonFocus,
          onPressed: () async {
            await updateService.cancelDownload();
          },
          isPrimary: false,
          autofocus: true,
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }

  Widget _buildInstallButton(
      BuildContext context, AppUpdateService updateService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _DialogButton(
          focusNode: _updateButtonFocus,
          onPressed: () => updateService.installUpdate(),
          isPrimary: true,
          autofocus: true,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.install_mobile, size: 20),
              SizedBox(width: 8),
              Text('Installieren'),
            ],
          ),
        ),
      ],
    );
  }
}

/// TV-optimized button for dialogs with focus handling
class _DialogButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool autofocus;
  final Widget child;

  const _DialogButton({
    required this.focusNode,
    required this.onPressed,
    required this.isPrimary,
    this.autofocus = false,
    required this.child,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onPressed?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(8),
            border: _isFocused
                ? Border.all(color: Colors.white, width: 2)
                : null,
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: (widget.isPrimary
                              ? AppTheme.primaryColor
                              : Colors.white)
                          .withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: 16,
              fontWeight: _isFocused ? FontWeight.bold : FontWeight.w500,
              color: _getTextColor(),
            ),
            child: IconTheme(
              data: IconThemeData(color: _getTextColor()),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (widget.isPrimary) {
      return _isFocused
          ? AppTheme.primaryColor
          : AppTheme.primaryColor.withValues(alpha: 0.8);
    }
    return _isFocused
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.1);
  }

  Color _getTextColor() {
    if (widget.isPrimary) {
      return Colors.white;
    }
    return _isFocused ? Colors.white : Colors.white.withValues(alpha: 0.8);
  }
}
