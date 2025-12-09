import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Widget d'icône de catégorie minimaliste
///
/// Style par défaut : Cercle gris clair, icône grise
/// État sélectionné : Cercle bleu nuit, icône blanche
class CategoryIconWidget extends StatelessWidget {
  final String? iconKey;
  final bool isSelected;
  final double size;

  const CategoryIconWidget({
    super.key,
    this.iconKey,
    this.isSelected = false,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: FaIcon(
          _getCategoryIcon(iconKey),
          color: isSelected ? Colors.white : Colors.grey[700],
          size: size * 0.4,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? iconKey) {
    if (iconKey == null) return FontAwesomeIcons.question;
    switch (iconKey) {
      case 'utensils':
        return FontAwesomeIcons.utensils;
      case 'taxi':
        return FontAwesomeIcons.taxi;
      case 'bolt':
        return FontAwesomeIcons.bolt;
      case 'heartPulse':
        return FontAwesomeIcons.heartPulse;
      case 'exchangeAlt':
        return FontAwesomeIcons.rightLeft;
      case 'gamepad':
        return FontAwesomeIcons.gamepad;
      case 'shoppingCart':
        return FontAwesomeIcons.cartShopping;
      case 'home':
        return FontAwesomeIcons.house;
      case 'graduation':
        return FontAwesomeIcons.graduationCap;
      case 'plane':
        return FontAwesomeIcons.plane;
      default:
        return FontAwesomeIcons.tag;
    }
  }
}
