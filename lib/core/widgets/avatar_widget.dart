import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../network/token_service.dart';

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
    String cleanName = name.replaceAll(RegExp(r'^[?\s]+'), '').trim();
    if (cleanName.isEmpty) cleanName = 'BNX';
    
    String firstLetter = 'B';
    for (int i = 0; i < cleanName.length; i++) {
      final char = cleanName[i];
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
        firstLetter = char.toUpperCase();
        break;
      }
    }

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      final url = avatarUrl!.trim();
      final isDataUri = url.startsWith('data:image') || url.contains(';base64,');
      final isRelativeApi = url.startsWith('/');
      final isNetwork = url.startsWith('http://') || url.startsWith('https://') || isRelativeApi;

      Widget imageWidget;
      if (isDataUri) {
        try {
          final commaIndex = url.indexOf(',');
          final base64Str = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
          final bytes = base64Decode(base64Str.trim());
          imageWidget = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildLetterAvatar(firstLetter),
          );
        } catch (_) {
          imageWidget = _buildLetterAvatar(firstLetter);
        }
      } else if (isNetwork) {
        final absoluteUrl = isRelativeApi ? '${ApiClient.baseUrl}$url' : url;
        final token = TokenService.cachedAccessToken;
        final headers = <String, String>{
          'Cache-Control': 'no-cache',
        };
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        imageWidget = Image.network(
          absoluteUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          headers: headers,
          errorBuilder: (context, error, stackTrace) {
            print('[AVATAR IMAGE LOAD ERROR] URL: $absoluteUrl | Error: $error');
            return _buildLetterAvatar(firstLetter);
          },
        );
      } else {
        final file = File(url);
        if (file.existsSync()) {
          imageWidget = Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildLetterAvatar(firstLetter),
          );
        } else {
          imageWidget = _buildLetterAvatar(firstLetter);
        }
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: imageWidget,
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
