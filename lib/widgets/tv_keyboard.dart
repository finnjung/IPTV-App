import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact on-screen keyboard optimized for TV remote control navigation
class TvKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmit;
  final VoidCallback? onClose;
  final String? hintText;
  final bool autofocus;
  final bool showInputField;

  const TvKeyboard({
    super.key,
    required this.controller,
    this.onSubmit,
    this.onClose,
    this.hintText,
    this.autofocus = true,
    this.showInputField = true,
  });

  @override
  State<TvKeyboard> createState() => _TvKeyboardState();
}

class _TvKeyboardState extends State<TvKeyboard> {
  // Keyboard layout - SPACE and DEL integrated in last row
  static const List<List<String>> _keyboardLayout = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['q', 'w', 'e', 'r', 't', 'z', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', '@'],
    ['y', 'x', 'c', 'v', 'b', 'n', 'm', '.', '-', '/'],
    ['SPACE', ':', '_', '#', 'DEL'],
  ];

  // URL snippets for quick insertion
  static const List<String> _snippetKeys = ['http://', 'https://', '.com', '.de'];

  int _focusedRow = 0;
  int _focusedCol = 0;
  bool _isOnSnippetCol = false;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _keyboardFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  String get _currentKey {
    if (_isOnSnippetCol) {
      return _snippetKeys[_focusedRow.clamp(0, _snippetKeys.length - 1)];
    }
    final row = _keyboardLayout[_focusedRow];
    return row[_focusedCol.clamp(0, row.length - 1)];
  }

  void _handleKeyPress(String key) {
    switch (key) {
      case 'SPACE':
        widget.controller.text += ' ';
        break;
      case 'DEL':
        if (widget.controller.text.isNotEmpty) {
          widget.controller.text = widget.controller.text
              .substring(0, widget.controller.text.length - 1);
        }
        break;
      default:
        widget.controller.text += key;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_isOnSnippetCol) {
          if (_focusedRow > 0) {
            _focusedRow--;
          }
        } else if (_focusedRow > 0) {
          _focusedRow--;
          _focusedCol = _focusedCol.clamp(0, _keyboardLayout[_focusedRow].length - 1);
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_isOnSnippetCol) {
          if (_focusedRow < _snippetKeys.length - 1) {
            _focusedRow++;
          }
        } else if (_focusedRow < _keyboardLayout.length - 1) {
          _focusedRow++;
          _focusedCol = _focusedCol.clamp(0, _keyboardLayout[_focusedRow].length - 1);
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        if (_isOnSnippetCol) {
          // Snippet -> keyboard
          _isOnSnippetCol = false;
          _focusedRow = _focusedRow.clamp(0, _keyboardLayout.length - 1);
          _focusedCol = _keyboardLayout[_focusedRow].length - 1;
        } else if (_focusedCol > 0) {
          _focusedCol--;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        if (_isOnSnippetCol) {
          // Do nothing, already at right edge
        } else {
          final maxCol = _keyboardLayout[_focusedRow].length - 1;
          if (_focusedCol < maxCol) {
            _focusedCol++;
          } else {
            // Right edge of keyboard -> Snippets
            _isOnSnippetCol = true;
            _focusedRow = _focusedRow.clamp(0, _snippetKeys.length - 1);
          }
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _handleKeyPress(_currentKey);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      widget.onClose?.call();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _handleKeyPress('DEL');
      return KeyEventResult.handled;
    }

    // Handle direct character input for physical keyboards
    final character = event.character;
    if (character != null &&
        character.length == 1 &&
        character.codeUnitAt(0) >= 32 &&
        character.codeUnitAt(0) != 127) {
      widget.controller.text += character;
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withAlpha(50),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keyboard section
            Column(
              mainAxisSize: MainAxisSize.min,
              children: _keyboardLayout.asMap().entries.map((entry) {
                final rowIndex = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: row.asMap().entries.map((charEntry) {
                      final colIndex = charEntry.key;
                      final char = charEntry.value;
                      final isFocused = !_isOnSnippetCol &&
                          _focusedRow == rowIndex &&
                          _focusedCol == colIndex;

                      // Special keys (SPACE, DEL) get icons
                      if (char == 'SPACE' || char == 'DEL') {
                        return _SpecialKeyButton(
                          keyType: char,
                          isFocused: isFocused,
                          onTap: () => _handleKeyPress(char),
                        );
                      }

                      return _KeyButton(
                        label: char.toUpperCase(),
                        isFocused: isFocused,
                        onTap: () => _handleKeyPress(char),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),

            // Vertical divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: 1,
                height: 180,
                color: Colors.white.withAlpha(30),
              ),
            ),

            // Snippets column (on the side)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: _snippetKeys.asMap().entries.map((entry) {
                final index = entry.key;
                final snippet = entry.value;
                final isFocused = _isOnSnippetCol && _focusedRow == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _SnippetButton(
                    label: snippet,
                    isFocused: isFocused,
                    onTap: () => _handleKeyPress(snippet),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final bool isFocused;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    required this.isFocused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isFocused ? Colors.white : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: isFocused ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: Colors.white.withAlpha(60),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isFocused ? FontWeight.bold : FontWeight.w500,
              color: isFocused ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialKeyButton extends StatelessWidget {
  final String keyType;
  final bool isFocused;
  final VoidCallback onTap;

  const _SpecialKeyButton({
    required this.keyType,
    required this.isFocused,
    required this.onTap,
  });

  IconData get _icon {
    switch (keyType) {
      case 'SPACE':
        return Icons.space_bar;
      case 'DEL':
        return Icons.backspace_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: keyType == 'SPACE' ? 80 : 52,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isFocused ? Colors.white : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: isFocused ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: Colors.white.withAlpha(60),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          _icon,
          size: 20,
          color: isFocused ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class _SnippetButton extends StatelessWidget {
  final String label;
  final bool isFocused;
  final VoidCallback onTap;

  const _SnippetButton({
    required this.label,
    required this.isFocused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 70,
        height: 36,
        decoration: BoxDecoration(
          color: isFocused ? colorScheme.primary : colorScheme.primary.withAlpha(40),
          borderRadius: BorderRadius.circular(6),
          border: isFocused ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withAlpha(100),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isFocused ? FontWeight.bold : FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
