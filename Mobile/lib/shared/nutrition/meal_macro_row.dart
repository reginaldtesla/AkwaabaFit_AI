import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Protein / carbs / fat row (e.g. `38g P · 18g C · 26g F`) — no pairing advice.
class MealMacroRow extends StatelessWidget {
  const MealMacroRow({
    super.key,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fontSize = 12,
    this.spacing = 16,
  });

  final int proteinG;
  final int carbsG;
  final int fatG;
  final double fontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MacroChip(value: '${proteinG}g', label: 'P', fontSize: fontSize),
        SizedBox(width: spacing),
        _MacroChip(value: '${carbsG}g', label: 'C', fontSize: fontSize),
        SizedBox(width: spacing),
        _MacroChip(value: '${fatG}g', label: 'F', fontSize: fontSize),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.value,
    required this.label,
    required this.fontSize,
  });

  final String value;
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey.shade700,
        ),
        children: [
          TextSpan(text: value),
          const TextSpan(text: ' '),
          TextSpan(
            text: label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
