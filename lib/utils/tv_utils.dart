import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Platform channel for TV detection on Android
const _tvDetectionChannel = MethodChannel('com.iptv.iptv_app/tv_detection');

/// Utility class for Android TV / Fire TV support
class TvUtils {
  static bool? _isTvDevice;
  static bool _manualTvMode = false;
  static bool _initialized = false;

  /// Initialize TV detection (call this early in app startup)
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb || !Platform.isAndroid) {
      _isTvDevice = false;
      return;
    }

    try {
      // Check if device is in TV mode via platform channel
      final bool isTv = await _tvDetectionChannel.invokeMethod('isTvDevice');
      final bool hasLeanback = await _tvDetectionChannel.invokeMethod('hasLeanbackFeature');
      _isTvDevice = isTv || hasLeanback;
    } catch (e) {
      // Platform channel not available, default to false
      _isTvDevice = false;
    }
  }

  /// Manually enable TV mode (useful for testing or user preference)
  static void setTvMode(bool enabled) {
    _manualTvMode = enabled;
  }

  /// Check if running on a TV device (Android TV, Fire TV, etc.)
  /// Returns true ONLY for actual TV devices, NOT for desktop platforms
  static bool get isTvDevice {
    if (_manualTvMode) return true;

    // Return cached value if available
    if (_isTvDevice != null) return _isTvDevice!;

    if (kIsWeb) {
      return false;
    }

    // Desktop platforms have physical keyboards - no TV keyboard needed
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return false;
    }

    // iOS devices are never TVs
    if (Platform.isIOS) {
      return false;
    }

    // On Android, check the cached detection result
    // If not initialized yet, return false (safe default)
    return _isTvDevice ?? false;
  }

  /// Check if the app should use TV-optimized UI
  /// This is true for TV devices OR when manually enabled
  static bool get useTvInterface => _manualTvMode || isTvDevice;

  /// Check if running on a platform that needs D-pad navigation
  /// This includes TV and desktop for keyboard navigation
  static bool get needsDpadNavigation {
    if (kIsWeb) return false;
    return Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux;
  }

  /// Focus highlight color for TV
  static Color get focusColor => Colors.white;

  /// Focus border width
  static double get focusBorderWidth => 3.0;

  /// Focus scale factor when item is focused
  static double get focusScale => 1.05;

  /// Minimum touch target size for TV (48dp recommended)
  static double get minTouchTarget => 48.0;
}

/// A widget that wraps any child with focus handling for TV navigation
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final VoidCallback? onFocus;
  final VoidCallback? onUnfocus;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool showFocusDecoration;
  final BorderRadius? borderRadius;
  final Color? focusColor;
  final double scale;

  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.onFocus,
    this.onUnfocus,
    this.autofocus = false,
    this.focusNode,
    this.showFocusDecoration = true,
    this.borderRadius,
    this.focusColor,
    this.scale = 1.05,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() {
      _isFocused = hasFocus;
    });

    if (hasFocus) {
      _animationController.forward();
      widget.onFocus?.call();
    } else {
      _animationController.reverse();
      widget.onUnfocus?.call();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle Select/Enter/Space for activation
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onSelect?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: widget.showFocusDecoration
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius:
                        widget.borderRadius ?? BorderRadius.circular(12),
                    border: _isFocused
                        ? Border.all(
                            color:
                                widget.focusColor ?? TvUtils.focusColor,
                            width: TvUtils.focusBorderWidth,
                          )
                        : Border.all(
                            color: Colors.transparent,
                            width: TvUtils.focusBorderWidth,
                          ),
                    boxShadow: _isFocused
                        ? [
                            BoxShadow(
                              color: (widget.focusColor ?? TvUtils.focusColor)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    );
  }
}

/// A button optimized for TV navigation with clear focus states
class TvButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool autofocus;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? focusedBackgroundColor;
  final BorderRadius? borderRadius;

  const TvButton({
    super.key,
    required this.child,
    this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.padding,
    this.backgroundColor,
    this.focusedBackgroundColor,
    this.borderRadius,
  });

  @override
  State<TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<TvButton> {
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

  void _handleFocusChange(bool hasFocus) {
    setState(() {
      _isFocused = hasFocus;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onPressed?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surface;
    final focusBgColor =
        widget.focusedBackgroundColor ?? theme.colorScheme.primary;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _isFocused ? focusBgColor : bgColor,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            border: _isFocused
                ? Border.all(color: Colors.white, width: 2)
                : null,
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: focusBgColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: theme.textTheme.labelLarge!.copyWith(
              color: _isFocused ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: _isFocused ? FontWeight.bold : FontWeight.normal,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A scroll controller that ensures focused items are visible
class TvScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Hide scrollbars on TV as they're controlled by focus
    if (TvUtils.isTvDevice) {
      return child;
    }
    return super.buildScrollbar(context, child, details);
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use snapping physics on TV for better navigation
    if (TvUtils.isTvDevice) {
      return const ClampingScrollPhysics();
    }
    return super.getScrollPhysics(context);
  }
}

/// Extension to help scroll to focused widget
extension ScrollToFocused on ScrollController {
  void scrollToFocusedItem(
    BuildContext context, {
    double alignment = 0.5,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && hasClients) {
      final offset = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;
      final scrollOffset = offset.dx + (size.width * alignment);

      animateTo(
        scrollOffset.clamp(0.0, position.maxScrollExtent),
        duration: duration,
        curve: Curves.easeOut,
      );
    }
  }
}

/// A focus traversal policy for TV-style grid navigation
/// Uses ReadingOrderTraversalPolicy as base for proper left-to-right, top-to-bottom navigation
class TvGridFocusTraversalPolicy extends ReadingOrderTraversalPolicy {
  final int crossAxisCount;

  TvGridFocusTraversalPolicy({required this.crossAxisCount});
}
