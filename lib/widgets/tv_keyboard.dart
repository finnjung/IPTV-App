import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// On-screen keyboard optimized for TV remote control navigation
class TvKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmit;
  final VoidCallback? onClose;
  final String? hintText;
  final bool autofocus;
  final bool showInputField; // Whether to show the built-in input display

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
  static const List<String> _qwertyRows = [
    '1234567890',
    'qwertzuiop',
    'asdfghjkl',
    'yxcvbnm.-/',
    '@:_#',
  ];

  // URL snippets for quick insertion
  static const List<String> _snippetKeys = ['http://', 'https://', '.com', '.de'];

  static const List<String> _specialKeys = ['SPACE', 'DEL', 'CLEAR', 'OK'];

  bool _isOnSnippetRow = false;

  int _focusedRow = 0;
  int _focusedCol = 0;
  bool _isOnSpecialRow = false;
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
    if (_isOnSpecialRow) {
      return _specialKeys[_focusedCol.clamp(0, _specialKeys.length - 1)];
    }
    if (_isOnSnippetRow) {
      return _snippetKeys[_focusedCol.clamp(0, _snippetKeys.length - 1)];
    }
    final row = _qwertyRows[_focusedRow];
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
      case 'CLEAR':
        widget.controller.clear();
        break;
      case 'OK':
        widget.onSubmit?.call();
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
        if (_isOnSpecialRow) {
          // Special -> Snippet row
          _isOnSpecialRow = false;
          _isOnSnippetRow = true;
          _focusedCol = _focusedCol.clamp(0, _snippetKeys.length - 1);
        } else if (_isOnSnippetRow) {
          // Snippet -> last qwerty row
          _isOnSnippetRow = false;
          _focusedRow = _qwertyRows.length - 1;
          _focusedCol = _focusedCol.clamp(0, _qwertyRows[_focusedRow].length - 1);
        } else if (_focusedRow > 0) {
          _focusedRow--;
          _focusedCol = _focusedCol.clamp(0, _qwertyRows[_focusedRow].length - 1);
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_isOnSpecialRow) {
          // Already at bottom, do nothing
        } else if (_isOnSnippetRow) {
          // Snippet -> Special row
          _isOnSnippetRow = false;
          _isOnSpecialRow = true;
          _focusedCol = _focusedCol.clamp(0, _specialKeys.length - 1);
        } else if (_focusedRow < _qwertyRows.length - 1) {
          _focusedRow++;
          _focusedCol = _focusedCol.clamp(0, _qwertyRows[_focusedRow].length - 1);
        } else {
          // Last qwerty row -> Snippet row
          _isOnSnippetRow = true;
          _focusedCol = _focusedCol.clamp(0, _snippetKeys.length - 1);
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        if (_focusedCol > 0) {
          _focusedCol--;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        int maxCol;
        if (_isOnSpecialRow) {
          maxCol = _specialKeys.length - 1;
        } else if (_isOnSnippetRow) {
          maxCol = _snippetKeys.length - 1;
        } else {
          maxCol = _qwertyRows[_focusedRow].length - 1;
        }
        if (_focusedCol < maxCol) {
          _focusedCol++;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
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

    // Handle backspace/delete BEFORE character input check
    // On Mac, delete key sends a character (U+007F) which we don't want to insert
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _handleKeyPress('DEL');
      return KeyEventResult.handled;
    }

    // Handle direct character input for physical keyboards
    final character = event.character;
    if (character != null &&
        character.length == 1 &&
        character.codeUnitAt(0) >= 32 && // Ignore control characters
        character.codeUnitAt(0) != 127) { // Ignore DEL character
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withAlpha(50),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text input display (optional)
            if (widget.showInputField) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withAlpha(50),
                  ),
                ),
                child: Text(
                  widget.controller.text.isEmpty
                      ? widget.hintText ?? 'Suchen...'
                      : widget.controller.text,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: widget.controller.text.isEmpty
                        ? Colors.white.withAlpha(100)
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Keyboard rows
            ..._qwertyRows.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row.split('').asMap().entries.map((charEntry) {
                    final colIndex = charEntry.key;
                    final char = charEntry.value;
                    final isFocused = !_isOnSpecialRow &&
                        !_isOnSnippetRow &&
                        _focusedRow == rowIndex &&
                        _focusedCol == colIndex;
                    return _KeyButton(
                      label: char.toUpperCase(),
                      isFocused: isFocused,
                      onTap: () => _handleKeyPress(char),
                    );
                  }).toList(),
                ),
              );
            }),

            const SizedBox(height: 8),

            // URL Snippet row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _snippetKeys.asMap().entries.map((entry) {
                  final index = entry.key;
                  final snippet = entry.value;
                  final isFocused = _isOnSnippetRow && _focusedCol == index;
                  return _KeyButton(
                    label: snippet,
                    isFocused: isFocused,
                    isSnippet: true,
                    onTap: () => _handleKeyPress(snippet),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Special keys row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _specialKeys.asMap().entries.map((entry) {
                  final index = entry.key;
                  final key = entry.value;
                  final isFocused = _isOnSpecialRow && _focusedCol == index;
                  return _KeyButton(
                    label: key,
                    isFocused: isFocused,
                    isWide: true,
                    isAction: key == 'OK',
                    onTap: () => _handleKeyPress(key),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // Hint text
            Text(
              'Pfeiltasten zum Navigieren, Enter zum Auswählen',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withAlpha(100),
              ),
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
  final bool isWide;
  final bool isAction;
  final bool isSnippet;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    required this.isFocused,
    this.isWide = false,
    this.isAction = false,
    this.isSnippet = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Determine width based on type
    double width;
    if (isSnippet) {
      width = 90; // Snippets are wider
    } else if (isWide) {
      width = 80;
    } else {
      width = 40;
    }

    // Determine font size
    double fontSize;
    if (isSnippet) {
      fontSize = 13;
    } else if (isWide) {
      fontSize = 12;
    } else {
      fontSize = 16;
    }

    // Snippet unfocused color is slightly different (hint of primary)
    Color unfocusedColor = isSnippet
        ? colorScheme.primary.withAlpha(40)
        : Colors.white.withAlpha(20);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: width,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isFocused
              ? (isAction ? colorScheme.primary : Colors.white)
              : unfocusedColor,
          borderRadius: BorderRadius.circular(8),
          border: isFocused
              ? Border.all(color: Colors.white, width: 2)
              : null,
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: (isAction ? colorScheme.primary : Colors.white)
                        .withAlpha(60),
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
              fontSize: fontSize,
              fontWeight: isFocused ? FontWeight.bold : FontWeight.w500,
              color: isFocused
                  ? (isAction ? Colors.white : Colors.black)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
