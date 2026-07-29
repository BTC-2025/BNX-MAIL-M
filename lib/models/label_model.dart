import 'package:flutter/material.dart';

class LabelModel {
  final String id;
  final String name;
  final Color color;

  const LabelModel({required this.id, required this.name, required this.color});

  factory LabelModel.fromJson(Map<String, dynamic> json) {
    final colorHex = json['color']?.toString() ??
        json['colorHex']?.toString() ??
        json['color_hex']?.toString() ??
        json['hex']?.toString() ??
        '';
    Color color = const Color(0xFF195BAC); // BNX brand blue fallback
    if (colorHex.isNotEmpty) {
      try {
        final hex = colorHex
            .replaceAll('#', '')
            .replaceAll('0x', '')
            .replaceAll('0X', '');
        final padded = hex.length == 6 ? 'FF$hex' : hex;
        color = Color(int.parse(padded, radix: 16));
      } catch (_) {
        // keep fallback
      }
    }
    return LabelModel(
      id:
          json['id']?.toString() ??
          json['_id']?.toString() ??
          json['labelId']?.toString() ??
          '',
      name: json['name']?.toString() ?? json['label']?.toString() ?? '',
      color: color,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color':
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
  };

  LabelModel copyWith({String? id, String? name, Color? color}) {
    return LabelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
