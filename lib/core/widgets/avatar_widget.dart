import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;
  final double fontSize;

  const AvatarWidget({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 40.0,
    this.fontSize = 16.0,
  });

  Color _getColorForLetter(String letter) {
    if (letter.isEmpty) return Colors.blue;
    final int code = letter.toUpperCase().codeUnitAt(0);
    // A simple hash function to assign stable colors from a premium palette
    final List<Color> palette = [
      const Color(0xFF1D4ED8), // Blue
      const Color(0xFF0D9488), // Teal
      const Color(0xFF059669), // Green
      const Color(0xFFD97706), // Amber
      const Color(0xFFDC2626), // Red
      const Color(0xFF7C3AED), // Purple
      const Color(0xFFDB2777), // Pink
      const Color(0xFF2563EB), // Light Blue
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF0891B2), // Cyan
    ];
    return palette[code % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildLetterAvatar(firstLetter),
        ),
      );
    }
    return _buildLetterAvatar(firstLetter);
  }

  Widget _buildLetterAvatar(String letter) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getColorForLetter(name),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
