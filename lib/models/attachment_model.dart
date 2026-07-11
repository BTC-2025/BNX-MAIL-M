class AttachmentModel {
  final String fileName;
  final String fileType;
  final String fileSize;

  const AttachmentModel({
    required this.fileName,
    required this.fileType,
    required this.fileSize,
  });

  AttachmentModel copyWith({
    String? fileName,
    String? fileType,
    String? fileSize,
  }) {
    return AttachmentModel(
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}
