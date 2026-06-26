import 'package:flutter/material.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Un widget simple qui affiche un curseur vertical clignotant
/// pour simuler un champ de texte natif.
class BlinkingCursor extends StatefulWidget {
  final Color? color;
  final double height;
  final double width;

  const BlinkingCursor({
    super.key,
    this.color,
    this.height = 24.0,
    this.width = 2.0,
  });

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: widget.color ?? AppTheme.primaryColor,
      ),
    );
  }
}
