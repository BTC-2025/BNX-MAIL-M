/// Formats a raw byte count into a human-readable size string.
String _formatSize(dynamic raw) {
  if (raw is String &&
      (raw.endsWith('B') ||
          raw.endsWith('KB') ||
          raw.endsWith('MB') ||
          raw.endsWith('GB') ||
          raw.endsWith('TB'))) {
    return raw;
  }
  final bytes = raw is int ? raw : int.tryParse(raw?.toString() ?? '0') ?? 0;
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

/// Derives a short file-type label from a MIME type or filename extension.
String _extractFileType(String mimeOrName) {
  if (mimeOrName.isEmpty) return 'FILE';
  final lower = mimeOrName.toLowerCase();
  if (lower.contains('pdf')) return 'PDF';
  if (lower.contains('word') ||
      lower.contains('docx') ||
      lower.endsWith('.doc')) {
    return 'DOC';
  }
  if (lower.contains('sheet') ||
      lower.contains('xlsx') ||
      lower.endsWith('.xls')) {
    return 'XLS';
  }
  if (lower.contains('image') ||
      lower.contains('png') ||
      lower.contains('jpg') ||
      lower.contains('jpeg')) {
    return 'IMG';
  }
  if (lower.contains('zip') || lower.contains('rar') || lower.contains('tar')) {
    return 'ZIP';
  }
  if (lower.contains('text') || lower.endsWith('.txt')) return 'TXT';
  if (lower.contains('pptx') || lower.endsWith('.ppt')) return 'PPT';
  final ext = lower.split('.').last.toUpperCase();
  return ext.length <= 5 ? ext : 'FILE';
}

class AttachmentModel {
  final String fileName;
  final String fileType;
  final String fileSize;
  final String? filePath;

  const AttachmentModel({
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.filePath,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    final name =
        json['filename']?.toString() ??
        json['fileName']?.toString() ??
        json['name']?.toString() ??
        json['title']?.toString() ??
        json['originalName']?.toString() ??
        json['file']?.toString() ??
        'attachment';
    final mime =
        json['contentType']?.toString() ??
        json['mimeType']?.toString() ??
        json['type']?.toString() ??
        json['mime']?.toString() ??
        json['content_type']?.toString() ??
        '';
    final rawPath =
        json['filePath']?.toString() ??
        json['url']?.toString() ??
        json['downloadUrl']?.toString() ??
        json['attachmentUrl']?.toString() ??
        json['uri']?.toString() ??
        json['file_url']?.toString() ??
        json['path']?.toString() ??
        json['content']?.toString() ??
        json['base64']?.toString() ??
        json['base64Data']?.toString() ??
        json['data']?.toString() ??
        (json['id'] != null ? '/api/mail/attachments/${json['id']}' : null) ??
        (json['attachmentId'] != null ? '/api/mail/attachments/${json['attachmentId']}' : null) ??
        (json['attachment_id'] != null ? '/api/mail/attachments/${json['attachment_id']}' : null);

    return AttachmentModel(
      fileName: name,
      fileType: _extractFileType(mime.isNotEmpty ? mime : name),
      fileSize: _formatSize(
        json['size'] ?? json['fileSize'] ?? json['length'] ?? json['bytes'] ?? json['file_size'] ?? 0,
      ),
      filePath: rawPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'filename': fileName,
    'contentType': fileType,
    'fileSize': fileSize,
  };

  AttachmentModel copyWith({
    String? fileName,
    String? fileType,
    String? fileSize,
    String? filePath,
  }) {
    return AttachmentModel(
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
    );
  }
}
