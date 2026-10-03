import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/token_service.dart';
import 'storage_repository.dart';

/// Model representing a backed-up file in the Mail Backup & Data Vault
/// from GET /api/vault
class VaultFile {
  final int id;
  final String filename;
  final String contentType;
  final int size;
  final DateTime? createdAt;

  const VaultFile({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.size,
    this.createdAt,
  });

  factory VaultFile.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final createdRaw = json['createdAt']?.toString();
    if (createdRaw != null && createdRaw.isNotEmpty) {
      try {
        parsedDate = DateTime.parse(createdRaw);
      } catch (_) {}
    }

    return VaultFile(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      filename: json['filename']?.toString() ?? 'untitled_backup',
      contentType: json['contentType']?.toString() ?? 'application/octet-stream',
      size: json['size'] is num ? (json['size'] as num).toInt() : 0,
      createdAt: parsedDate,
    );
  }

  String get sizeFormatted => StorageQuota.formatBytes(size);

  String get createdAtFormatted {
    if (createdAt == null) return 'Unknown date';
    final d = createdAt!.toLocal();
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[(d.month - 1).clamp(0, 11)];
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$month ${d.day}, ${d.year} at $hour:$minute';
  }

  bool get isZip => filename.toLowerCase().endsWith('.zip') || contentType.contains('zip');
  bool get isCsv => filename.toLowerCase().endsWith('.csv') || contentType.contains('csv');
  bool get isPdf => filename.toLowerCase().endsWith('.pdf') || contentType.contains('pdf');
  bool get isMailArchive =>
      filename.toLowerCase().endsWith('.eml') ||
      filename.toLowerCase().endsWith('.mbox') ||
      contentType.contains('message');
}

/// Repository for handling Mail Backup & Data Vault APIs (Section 3)
class VaultRepository {
  /// GET /api/vault
  /// Fetches list of all backed-up files in user's vault
  static Future<List<VaultFile>> listVaultFiles() async {
    try {
      final res = await ApiClient.get('/api/vault');
      final dynamic rawList = res['data'] ?? res;
      if (rawList is List) {
        return rawList
            .whereType<Map<String, dynamic>>()
            .map((item) => VaultFile.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      StorageDebug.log('[VAULT ERROR] Failed to list vault files: $e');
      rethrow;
    }
  }

  /// POST /api/vault/upload
  /// Uploads and stores a backup archive or file in the Vault (multipart/form-data)
  static Future<VaultFile> uploadVaultFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ApiException(statusCode: 400, message: 'Selected file does not exist.');
      }

      final uri = Uri.parse('${ApiClient.baseUrl}/api/vault/upload');
      final token = await TokenService.getAccessToken();

      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Upload failed: ${response.body}',
        );
      }

      final dynamic decoded = response.body.isNotEmpty ? (response.body) : null;
      if (decoded != null) {
        return VaultFile(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          filename: file.uri.pathSegments.last,
          contentType: 'application/octet-stream',
          size: await file.length(),
          createdAt: DateTime.now(),
        );
      }

      return VaultFile(
        id: 0,
        filename: file.uri.pathSegments.last,
        contentType: 'application/octet-stream',
        size: await file.length(),
        createdAt: DateTime.now(),
      );
    } catch (e) {
      StorageDebug.log('[VAULT ERROR] Failed to upload vault file: $e');
      rethrow;
    }
  }

  /// DELETE /api/vault/{id}
  /// Deletes a backup from the Vault
  static Future<bool> deleteVaultFile(int id) async {
    try {
      final res = await ApiClient.delete('/api/vault/$id');
      return res['message'] != null || res['success'] == true;
    } catch (e) {
      StorageDebug.log('[VAULT ERROR] Failed to delete vault file $id: $e');
      rethrow;
    }
  }

  /// GET /api/vault/{id}/download
  /// Downloads raw backup file binary stream
  static Future<List<int>> downloadVaultFile(int id) async {
    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/api/vault/$id/download');
      final token = await TokenService.getAccessToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to download backup file ($id)',
        );
      }
      return response.bodyBytes;
    } catch (e) {
      StorageDebug.log('[VAULT ERROR] Failed to download vault file $id: $e');
      rethrow;
    }
  }
}
