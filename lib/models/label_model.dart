import 'package:flutter/material.dart';

class LabelModel {
  final String id;
  final String name;
  final Color color;

  const LabelModel({
    required this.id,
    required this.name,
    required this.color,
  });

  LabelModel copyWith({
    String? id,
    String? name,
    Color? color,
  }) {
    return LabelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
