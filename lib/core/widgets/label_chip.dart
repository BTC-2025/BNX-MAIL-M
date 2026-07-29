import 'package:flutter/material.dart';
import '../theme/colors.dart';

class LabelChip extends StatelessWidget {
  final String labelName;
  final Color? customColor;

  const LabelChip({super.key, required this.labelName, this.customColor});

  Color _getLabelColor(String name) {
    if (customColor != null) return customColor!;
    switch (name.toLowerCase()) {
      case 'work':
        return BNXColors.labelWork;
      case 'personal':
        return BNXColors.labelPersonal;
      case 'important':
        return BNXColors.labelImportant;
      case 'promotions':
        return BNXColors.labelPromotions;
      case 'social':
        return BNXColors.labelSocial;
      case 'updates':
        return BNXColors.labelUpdates;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getLabelColor(labelName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.24), width: 1),
      ),
      child: Text(
        labelName,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
