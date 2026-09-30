import 'package:flutter/material.dart';

/// Represents an application's allocated and used storage in the ecosystem.
class StorageAppData {
  final String id;
  final String name;
  final String subtitle;
  final double usedBytes;
  final double allocatedBytes;
  final String logoAsset;
  final Color brandColor;
  final int fileCount;
  final DateTime? lastSynced;

  const StorageAppData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.usedBytes,
    required this.allocatedBytes,
    required this.logoAsset,
    required this.brandColor,
    this.fileCount = 0,
    this.lastSynced,
  });

  double get usagePercentage => allocatedBytes > 0 ? (usedBytes / allocatedBytes).clamp(0.0, 1.0) : 0.0;
}

/// Represents a storage category breakdown (e.g., Documents, Images, Media).
class StorageCategoryData {
  final String label;
  final double usedBytes;
  final Color color;
  final IconData icon;

  const StorageCategoryData({
    required this.label,
    required this.usedBytes,
    required this.color,
    required this.icon,
  });
}

/// Represents a file tracked in Storage Usage analytics.
class StorageFileItem {
  final String id;
  final String name;
  final String extension;
  final double sizeBytes;
  final String originalLocation;
  final DateTime modifiedDate;
  final String owningApp;

  const StorageFileItem({
    required this.id,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.originalLocation,
    required this.modifiedDate,
    required this.owningApp,
  });
}

/// Represents an item currently in the Recycle Bin.
class RecycleBinItemModel {
  final String id;
  final String name;
  final String app;
  final String size;
  final String deletedDate;
  final String originalLocation;
  final String fileType;

  const RecycleBinItemModel({
    required this.id,
    required this.name,
    required this.app,
    required this.size,
    required this.deletedDate,
    required this.originalLocation,
    required this.fileType,
  });
}
