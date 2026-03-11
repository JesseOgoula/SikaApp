import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Widget d'icone de categorie minimaliste
///
/// Style par defaut : Cercle gris clair, icone grise
/// Etat selectionne : Cercle bleu nuit, icone blanche
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
          getCategoryIcon(iconKey),
          color: isSelected ? Colors.white : Colors.grey[700],
          size: size * 0.4,
        ),
      ),
    );
  }

  /// Map des icones disponibles pour les categories
  /// Utilise aussi par le picker d'icones lors de la creation de categorie
  static const Map<String, IconData> availableIcons = {
    'utensils': FontAwesomeIcons.utensils,
    'taxi': FontAwesomeIcons.taxi,
    'bolt': FontAwesomeIcons.bolt,
    'heartPulse': FontAwesomeIcons.heartPulse,
    'exchangeAlt': FontAwesomeIcons.rightLeft,
    'gamepad': FontAwesomeIcons.gamepad,
    'shoppingCart': FontAwesomeIcons.cartShopping,
    'home': FontAwesomeIcons.house,
    'graduation': FontAwesomeIcons.graduationCap,
    'plane': FontAwesomeIcons.plane,
    'briefcase': FontAwesomeIcons.briefcase,
    'gift': FontAwesomeIcons.gift,
    'music': FontAwesomeIcons.music,
    'palette': FontAwesomeIcons.palette,
    'dumbbell': FontAwesomeIcons.dumbbell,
    'paw': FontAwesomeIcons.paw,
    'baby': FontAwesomeIcons.baby,
    'scissors': FontAwesomeIcons.scissors,
    'wrench': FontAwesomeIcons.wrench,
    'book': FontAwesomeIcons.book,
    'phone': FontAwesomeIcons.phone,
    'wifi': FontAwesomeIcons.wifi,
    'shirt': FontAwesomeIcons.shirt,
    'church': FontAwesomeIcons.church,
    'handHoldingHeart': FontAwesomeIcons.handHoldingHeart,
    'piggyBank': FontAwesomeIcons.piggyBank,
    'receipt': FontAwesomeIcons.receipt,
    'tag': FontAwesomeIcons.tag,
  };

  /// Resoud la cle d'icone vers un IconData
  static IconData getCategoryIcon(String? iconKey) {
    if (iconKey == null) return FontAwesomeIcons.question;
    return availableIcons[iconKey] ?? FontAwesomeIcons.tag;
  }
}
