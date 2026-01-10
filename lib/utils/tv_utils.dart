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

/// An improved focus traversal policy that handles incomplete grid rows properly
/// When navigating up/down, it finds the nearest element in that direction
/// even if elements don't align geometrically (e.g., incomplete last row)
class FlexibleVerticalFocusTraversalPolicy extends FocusTraversalPolicy
    with DirectionalFocusTraversalPolicyMixin {

  /// Static flag that signals when the policy couldn't navigate further up
  /// MainNavigation checks this to know when to jump to the nav bar
  static bool shouldEscapeToNavBar = false;

  /// Filter nodes to only include actual interactive elements (reasonable size)
  /// This filters out Focus wrappers (0x0 or tiny) and large containers
  List<FocusNode> _filterContentNodes(Iterable<FocusNode> nodes) {
    return nodes.where((node) {
      final rect = node.rect;
      // Filter out nodes that are too small or too large
      // Content cards: ~130x200, Buttons: ~400x50, Small cards: ~90x90
      // Focus wrappers are often 0x0, containers are screen-sized
      final area = rect.width * rect.height;
      final isNotTooSmall = area > 3000 && rect.width > 50 && rect.height > 30;
      final isNotTooLarge = rect.width < 500 && rect.height < 400;
      return isNotTooSmall && isNotTooLarge;
    }).toList();
  }

  /// Groups nodes into rows based on their vertical position
  List<List<FocusNode>> _groupIntoRows(List<FocusNode> nodes) {
    if (nodes.isEmpty) return [];

    // Sort by vertical position first
    final sortedByY = List<FocusNode>.from(nodes);
    sortedByY.sort((a, b) => a.rect.center.dy.compareTo(b.rect.center.dy));

    final List<List<FocusNode>> rows = [];
    List<FocusNode> currentRow = [sortedByY.first];
    double currentRowY = sortedByY.first.rect.center.dy;

    for (int i = 1; i < sortedByY.length; i++) {
      final node = sortedByY[i];
      final nodeY = node.rect.center.dy;

      // If this node is more than 100 pixels below the current row, start a new row
      if ((nodeY - currentRowY).abs() > 100) {
        // Sort current row by X before adding
        currentRow.sort((a, b) => a.rect.center.dx.compareTo(b.rect.center.dx));
        rows.add(currentRow);
        currentRow = [node];
        currentRowY = nodeY;
      } else {
        currentRow.add(node);
      }
    }

    // Don't forget the last row
    if (currentRow.isNotEmpty) {
      currentRow.sort((a, b) => a.rect.center.dx.compareTo(b.rect.center.dx));
      rows.add(currentRow);
    }

    return rows;
  }

  @override
  Iterable<FocusNode> sortDescendants(
      Iterable<FocusNode> descendants, FocusNode currentNode) {
    final List<FocusNode> sorted = descendants.toList();
    sorted.sort((a, b) {
      final aRect = a.rect;
      final bRect = b.rect;
      final rowDiff = (aRect.center.dy - bRect.center.dy).abs();
      if (rowDiff > 100) {
        return aRect.center.dy.compareTo(bRect.center.dy);
      }
      return aRect.center.dx.compareTo(bRect.center.dx);
    });
    return sorted;
  }

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    // Reset the escape flag at the start of each navigation
    shouldEscapeToNavBar = false;

    // For horizontal navigation, use default behavior
    if (direction == TraversalDirection.left ||
        direction == TraversalDirection.right) {
      return super.inDirection(currentNode, direction);
    }

    final FocusScopeNode? scope = currentNode.nearestScope;
    if (scope == null) {
      debugPrint('[FocusPolicy] No scope found');
      return super.inDirection(currentNode, direction);
    }

    // Filter to only include actual content cards (nodes with reasonable size)
    final List<FocusNode> allNodes = _filterContentNodes(scope.traversalDescendants);

    // Make sure current node is included even if it didn't pass the filter
    if (!allNodes.contains(currentNode)) {
      allNodes.add(currentNode);
    }

    debugPrint('[FocusPolicy] Total content nodes: ${allNodes.length} (filtered from ${scope.traversalDescendants.length})');

    if (allNodes.isEmpty) {
      debugPrint('[FocusPolicy] No nodes found');
      return super.inDirection(currentNode, direction);
    }

    // Group nodes into rows
    final rows = _groupIntoRows(allNodes);
    debugPrint('[FocusPolicy] Grouped into ${rows.length} rows');
    for (int i = 0; i < rows.length; i++) {
      debugPrint('[FocusPolicy] Row $i: ${rows[i].length} elements, Y=${rows[i].isNotEmpty ? rows[i].first.rect.center.dy.toInt() : 0}');
    }

    if (rows.isEmpty) return super.inDirection(currentNode, direction);

    // Find which row the current node is in
    int currentRowIndex = -1;
    for (int r = 0; r < rows.length; r++) {
      final idx = rows[r].indexOf(currentNode);
      if (idx != -1) {
        currentRowIndex = r;
        break;
      }
    }

    debugPrint('[FocusPolicy] Current node in row: $currentRowIndex, direction: $direction');

    if (currentRowIndex == -1) {
      debugPrint('[FocusPolicy] Current node not found in any row!');
      return super.inDirection(currentNode, direction);
    }

    final currentRect = currentNode.rect;

    // Navigate to the target row
    int targetRowIndex;

    // If current row is small (like a button), just go to adjacent row without any skip logic
    if (rows[currentRowIndex].length <= 2) {
      targetRowIndex = direction == TraversalDirection.up
          ? currentRowIndex - 1
          : currentRowIndex + 1;
      debugPrint('[FocusPolicy] From small row, going directly to row $targetRowIndex');
    } else {
      // From a content row: skip small rows ONLY if there's a larger row beyond them
      // This skips buttons between content sections, but allows navigating to incomplete last rows
      if (direction == TraversalDirection.up) {
        targetRowIndex = currentRowIndex - 1;
        // Skip small rows only if there's a larger row above them to reach
        while (targetRowIndex >= 0 && rows[targetRowIndex].length <= 2) {
          // Check if there's any larger row above
          bool hasLargerRowAbove = false;
          for (int i = 0; i < targetRowIndex; i++) {
            if (rows[i].length > 2) {
              hasLargerRowAbove = true;
              break;
            }
          }
          if (hasLargerRowAbove) {
            debugPrint('[FocusPolicy] Skipping row $targetRowIndex with only ${rows[targetRowIndex].length} elements (larger row exists above)');
            targetRowIndex--;
          } else {
            // No larger row above, stop here - this is likely the top content
            debugPrint('[FocusPolicy] Stopping at row $targetRowIndex (no larger row above)');
            break;
          }
        }
      } else {
        targetRowIndex = currentRowIndex + 1;
        // Skip small rows only if there's a larger row below them to reach
        while (targetRowIndex < rows.length && rows[targetRowIndex].length <= 2) {
          // Check if there's any larger row below
          bool hasLargerRowBelow = false;
          for (int i = targetRowIndex + 1; i < rows.length; i++) {
            if (rows[i].length > 2) {
              hasLargerRowBelow = true;
              break;
            }
          }
          if (hasLargerRowBelow) {
            debugPrint('[FocusPolicy] Skipping row $targetRowIndex with only ${rows[targetRowIndex].length} elements (larger row exists below)');
            targetRowIndex++;
          } else {
            // No larger row below, stop here - this could be the last content row or a button
            debugPrint('[FocusPolicy] Stopping at row $targetRowIndex (no larger row below)');
            break;
          }
        }
      }
    }

    debugPrint('[FocusPolicy] Target row: $targetRowIndex');

    // Check bounds
    if (targetRowIndex < 0 || targetRowIndex >= rows.length) {
      debugPrint('[FocusPolicy] Target row out of bounds - signaling escape to nav bar');
      // Set flag so MainNavigation knows to jump to nav bar
      if (direction == TraversalDirection.up) {
        shouldEscapeToNavBar = true;
      }
      return false;
    }

    // If navigating UP and target row is way off-screen (Y < -500), let focus escape to nav bar
    // This prevents getting stuck scrolling through tons of off-screen content
    final targetRowY = rows[targetRowIndex].first.rect.center.dy;
    if (direction == TraversalDirection.up && targetRowY < -500) {
      debugPrint('[FocusPolicy] Target row at Y=$targetRowY is way off-screen, signaling escape to nav bar');
      shouldEscapeToNavBar = true;
      return false;
    }

    final targetRow = rows[targetRowIndex];
    if (targetRow.isEmpty) {
      debugPrint('[FocusPolicy] Target row is empty');
      return super.inDirection(currentNode, direction);
    }

    debugPrint('[FocusPolicy] Target row has ${targetRow.length} elements');

    // Find the horizontally closest element in the target row
    FocusNode? bestNode;
    double bestDistance = double.infinity;

    for (final node in targetRow) {
      final distance = (node.rect.center.dx - currentRect.center.dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestNode = node;
      }
    }

    if (bestNode != null) {
      final bestRect = bestNode.rect;
      debugPrint('[FocusPolicy] Focusing node at Y=${bestRect.center.dy.toInt()}, size=${bestRect.width.toInt()}x${bestRect.height.toInt()}');
      bestNode.requestFocus();
      return true;
    }

    // Fallback: just take the first element in the target row
    debugPrint('[FocusPolicy] Fallback: focusing first element in target row');
    targetRow.first.requestFocus();
    return true;
  }
}
