import 'package:flutter/material.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Clavier texte personnalisé style Neo-Bank (AZERTY) - Pleine largeur
class TextPad extends StatefulWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onBackspace;
  final VoidCallback onDone;

  const TextPad({
    super.key,
    required this.onKeyPressed,
    required this.onBackspace,
    required this.onDone,
  });

  @override
  State<TextPad> createState() => _TextPadState();
}

class _TextPadState extends State<TextPad> {
  bool _isUpperCase = true; // Premier caractère en majuscule
  bool _isCapsLock = false; // Mode verrouillage majuscules
  bool _showNumbers = false;
  DateTime _lastShiftTap = DateTime.now();

  final List<List<String>> _lettersLower = [
    ['a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm'],
    ['⇧', 'w', 'x', 'c', 'v', 'b', 'n', '⌫'],
    ['123', ' ', '✓'],
  ];

  final List<List<String>> _lettersUpper = [
    ['A', 'Z', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['Q', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'M'],
    ['⇧', 'W', 'X', 'C', 'V', 'B', 'N', '⌫'],
    ['123', ' ', '✓'],
  ];

  final List<List<String>> _numbers = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['-', '/', ':', ';', '(', ')', '€', '&', '@', '"'],
    ['ABC', '.', ',', '?', '!', "'", '⌫'],
    ['ABC', ' ', '✓'],
  ];

  List<List<String>> get _currentLayout {
    if (_showNumbers) return _numbers;
    return _isUpperCase ? _lettersUpper : _lettersLower;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 2,
        right: 2,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFD1D5DB),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _currentLayout.map((row) => _buildRow(row)).toList(),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((key) => _buildKey(key)).toList(),
      ),
    );
  }

  Widget _buildKey(String key) {
    final isSpecial =
        key == '⇧' || key == '⌫' || key == '123' || key == 'ABC' || key == '✓';
    final isSpace = key == ' ';

    // Flex values for different key types
    int flex = 1;
    if (isSpace) flex = 4;
    if (key == '⇧' || key == '⌫' || key == '123' || key == 'ABC') flex = 1;
    if (key == '✓') flex = 2;

    Color bgColor = Colors.white;
    Color textColor = Colors.black87;

    // Shift key colors - différent pour caps lock vs shift simple
    if (key == '⇧' && !_showNumbers) {
      if (_isCapsLock) {
        bgColor = AppTheme.secondaryColor; // Teal pour caps lock
        textColor = Colors.white;
      } else if (_isUpperCase) {
        bgColor = AppTheme.primaryColor;
        textColor = Colors.white;
      } else {
        bgColor = const Color(0xFFADB5BD);
      }
    } else if (key == '✓') {
      bgColor = AppTheme.primaryColor;
      textColor = Colors.white;
    } else if (isSpecial) {
      bgColor = const Color(0xFFADB5BD);
    }

    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _handleKeyPress(key),
        child: Container(
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(child: _buildKeyContent(key, textColor)),
        ),
      ),
    );
  }

  Widget _buildKeyContent(String key, Color color) {
    if (key == '⌫') {
      return Icon(Icons.backspace_outlined, color: color, size: 20);
    }
    if (key == '⇧') {
      // Icône différente selon l'état
      IconData icon;
      if (_isCapsLock) {
        icon = Icons.keyboard_capslock;
      } else if (_isUpperCase) {
        icon = Icons.arrow_upward;
      } else {
        icon = Icons.keyboard_arrow_up;
      }
      return Icon(icon, color: color, size: 20);
    }
    if (key == '✓') {
      return const Text(
        'OK',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (key == ' ') {
      return Text(
        'espace',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Text(
      key,
      style: TextStyle(
        color: color,
        fontSize: key.length > 2 ? 12 : 18,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  void _handleKeyPress(String key) {
    if (key == '⌫') {
      widget.onBackspace();
    } else if (key == '⇧') {
      // Double-tap pour caps lock
      final now = DateTime.now();
      if (now.difference(_lastShiftTap).inMilliseconds < 400 && _isUpperCase) {
        // Double tap - toggle caps lock
        setState(() {
          _isCapsLock = !_isCapsLock;
          _isUpperCase = true;
        });
      } else {
        // Simple tap - toggle uppercase
        setState(() {
          if (_isCapsLock) {
            _isCapsLock = false;
            _isUpperCase = false;
          } else {
            _isUpperCase = !_isUpperCase;
          }
        });
      }
      _lastShiftTap = now;
    } else if (key == '123') {
      setState(() => _showNumbers = true);
    } else if (key == 'ABC') {
      setState(() => _showNumbers = false);
    } else if (key == '✓') {
      widget.onDone();
    } else {
      widget.onKeyPressed(key);
      // Si pas en caps lock, repasse en minuscules après une lettre
      if (_isUpperCase && !_isCapsLock && !_showNumbers) {
        setState(() => _isUpperCase = false);
      }
    }
  }
}
