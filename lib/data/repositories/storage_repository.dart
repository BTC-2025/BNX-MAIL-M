import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

/// Model representing mailbox storage quota from GET /api/mail/storage-quota
class StorageQuota {
  final String email;
  final int storageLimit;
  final int storageUsed;
  final double storagePercentage;

  const StorageQuota({
    required this.email,
    required this.storageLimit,
    required this.storageUsed,
    required this.storagePercentage,
  });

  // Getters for compatibility
  int get storageLimitBytes => storageLimit;
  int get storageUsedBytes => storageUsed;

  factory StorageQuota.fromJson(Map<String, dynamic> json) {
    // storageLimit must come from the API — no hardcoded default.
    final limitRaw = json['storageLimit'];
    if (limitRaw == null || limitRaw is! num) {
      throw const FormatException(
        'StorageQuota.fromJson: missing or invalid storageLimit in API response',
      );
    }
    final limit = limitRaw.toInt();

    final used = json['storageUsed'] is num
        ? (json['storageUsed'] as num).toInt()
        : 0;

    double pct;
    if (json['storagePercentage'] is num) {
      pct = (json['storagePercentage'] as num).toDouble();
    } else {
      pct = limit > 0 ? ((used / limit) * 100) : 0.0;
    }

    // Clamp between 0.0 and 100.0, protect against NaN / Infinity / negative.
    if (pct.isNaN || pct.isInfinite || pct < 0.0) {
      pct = 0.0;
    } else if (pct > 100.0) {
      pct = 100.0;
    }

    return StorageQuota(
      email: json['email']?.toString() ?? '',
      storageLimit: limit,
      storageUsed: used,
      storagePercentage: pct,
    );
  }

  static String formatBytes(int bytes) {
    if (bytes >= 1073741824) {
      final gb = bytes / 1073741824;
      return gb == gb.roundToDouble()
          ? '${gb.toInt()} GB'
          : '${gb.toStringAsFixed(2)} GB';
    } else if (bytes >= 1048576) {
      final mb = bytes / 1048576;
      return mb == mb.roundToDouble()
          ? '${mb.toInt()} MB'
          : '${mb.toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      final kb = bytes / 1024;
      return kb == kb.roundToDouble()
          ? '${kb.toInt()} KB'
          : '${kb.toStringAsFixed(2)} KB';
    } else {
      return '$bytes B';
    }
  }

  String get usedFormatted => formatBytes(storageUsed);
  String get limitFormatted => formatBytes(storageLimit);
  int get availableBytes => math.max(0, storageLimit - storageUsed);
  String get availableFormatted => formatBytes(availableBytes);

  double get fraction => (storagePercentage / 100.0).clamp(0.0, 1.0);
  double get progress => fraction;

  String get percentageFormatted {
    if (storagePercentage <= 0) return '0%';
    if (storagePercentage < 0.01) {
      return '${storagePercentage.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}%';
    }
    return '${storagePercentage.toStringAsFixed(2)}%';
  }

  String get status {
    if (storagePercentage < 70.0) return 'Normal';
    if (storagePercentage < 85.0) return 'Warning';
    if (storagePercentage < 95.0) return 'High';
    return 'Critical';
  }

  Color get statusColor {
    if (storagePercentage < 70.0) return const Color(0xFF10B981);
    if (storagePercentage < 85.0) return const Color(0xFFF59E0B);
    if (storagePercentage < 95.0) return const Color(0xFFEA580C);
    return const Color(0xFFEF4444);
  }

  String get statusDescription {
    if (storagePercentage < 70.0) {
      return 'STORAGE HEALTHY.\nWITHIN ALLOCATED QUOTA.';
    } else if (storagePercentage < 85.0) {
      return 'STORAGE USAGE ELEVATED.\nMONITOR CAPACITY.';
    } else if (storagePercentage < 95.0) {
      return 'STORAGE RUNNING LOW.\nCLEANUP RECOMMENDED.';
    } else {
      return 'STORAGE CRITICALLY FULL.\nACTION REQUIRED.';
    }
  }
}

/// Typedef for backwards compatibility
typedef StorageQuotaModel = StorageQuota;

class StorageDebug {
  static final List<String> logs = [];
  static void log(String s) {
    logs.add(s);
    print(s);
  }
}

/// Repository for handling real-time storage quota APIs.
class StorageRepository {
  static Future<StorageQuota>? _inFlightRequest;

  /// Resets in-flight request guard (used on account switch).
  static void resetInFlight() {
    _inFlightRequest = null;
  }

  /// Fetches real-time mailbox quota from GET /api/mail/storage-quota
  /// Deduplicates concurrent requests so only one HTTP request is active at a time.
  static Future<StorageQuota> fetchStorageQuota() async {
    if (_inFlightRequest != null) {
      StorageDebug.log('[STORAGE] Duplicate request prevented');
      return _inFlightRequest!;
    }
    _inFlightRequest = _performFetch();
    try {
      return await _inFlightRequest!;
    } finally {
      _inFlightRequest = null;
    }
  }

  static Future<StorageQuota> _performFetch() async {
    StorageDebug.log('[STORAGE] Fetching storage quota...');
    try {
      final res = await ApiClient.get('/api/mail/storage-quota');
      final bool success = res['success'] == true;
      final dynamic data = res['data'];

      if (!success || data is! Map<String, dynamic>) {
        throw ApiException(
          statusCode: 200,
          message: res['message']?.toString() ?? 'Invalid storage quota response',
        );
      }

      final quota = StorageQuota.fromJson(data);
      StorageDebug.log('[STORAGE] Quota loaded');
      StorageDebug.log('[STORAGE] Email: ${quota.email}');
      StorageDebug.log('[STORAGE] Used: ${quota.storageUsed} bytes');
      StorageDebug.log('[STORAGE] Limit: ${quota.storageLimit} bytes');
      StorageDebug.log('[STORAGE] Percentage: ${quota.storagePercentage}%');
      return quota;
    } catch (e) {
      StorageDebug.log('[STORAGE ERROR] Failed to fetch storage quota: $e');
      rethrow;
    }
  }

  /// Backward compatibility alias
  static Future<StorageQuota> getStorageQuota() => fetchStorageQuota();
}
