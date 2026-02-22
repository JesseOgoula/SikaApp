import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Clavier texte personnalisé style Neo-Bank (AZERTY) - Pleine largeur
/// Supporte les accents via appui long sur les voyelles et certaines consonnes
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

  // Map des accents disponibles par lettre (minuscule)
  static const Map<String, List<String>> _accentMap = {
    'a': ['à', 'â', 'ä', 'æ'],
    'e': ['é', 'è', 'ê', 'ë'],
    'i': ['î', 'ï'],
    'o': ['ô', 'ö', 'œ'],
    'u': ['ù', 'û', 'ü'],
    'y': ['ÿ'],
    'c': ['ç'],
    'n': ['ñ'],
  };

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

  /// Vérifie si une touche a des accents disponibles
  bool _hasAccents(String key) {
    return _accentMap.containsKey(key.toLowerCase());
  }

  /// Récupère les accents pour une touche (avec respect de la casse)
  List<String> _getAccentsForKey(String key) {
    final accents = _accentMap[key.toLowerCase()] ?? [];
    if (_isUpperCase || _isCapsLock) {
      return accents.map((a) => a.toUpperCase()).toList();
    }
    return accents;
  }

  Widget _buildKey(String key) {
    final isSpecial =
        key == '⇧' || key == '⌫' || key == '123' || key == 'ABC' || key == '✓';
    final isSpace = key == ' ';
    final hasAccent =
        !isSpecial && !isSpace && !_showNumbers && _hasAccents(key);

    // Flex values for different key types
    int flex = 1;
    if (isSpace) flex = 4;
    if (key == '⇧' || key == '⌫' || key == '123' || key == 'ABC') flex = 1;
    if (key == '✓') flex = 2;

    Color bgColor = Colors.white;
    Color textColor = Colors.black87;

    // Shift key colors
    if (key == '⇧' && !_showNumbers) {
      if (_isCapsLock) {
        bgColor = AppTheme.secondaryColor;
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
        onLongPress: hasAccent ? () => _showAccentPopup(key) : null,
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildKeyContent(key, textColor),
              // Petit indicateur d'accent disponible
              if (hasAccent)
                Positioned(
                  top: 2,
                  right: 4,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche le popup d'accents au-dessus de la touche
  void _showAccentPopup(String key) {
    HapticFeedback.mediumImpact();
    final accents = _getAccentsForKey(key);
    if (accents.isEmpty) return;

    // Inclure la lettre originale en premier
    final allOptions = [key, ...accents];

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => _AccentPicker(
        options: allOptions,
        onSelected: (selected) {
          Navigator.pop(ctx);
          widget.onKeyPressed(selected);
          // Si pas caps lock, repasse en minuscules
          if (_isUpperCase && !_isCapsLock && !_showNumbers) {
            setState(() => _isUpperCase = false);
          }
        },
      ),
    );
  }

  Widget _buildKeyContent(String key, Color color) {
    if (key == '⌫') {
      return Icon(Icons.backspace_outlined, color: color, size: 20);
    }
    if (key == '⇧') {
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
        setState(() {
          _isCapsLock = !_isCapsLock;
          _isUpperCase = true;
        });
      } else {
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

/// Widget popup pour sélectionner un accent
class _AccentPicker extends StatelessWidget {
  final List<String> options;
  final Function(String) onSelected;

  const _AccentPicker({required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: options.map((char) {
              return GestureDetector(
                onTap: () => onSelected(char),
                child: Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      char,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
