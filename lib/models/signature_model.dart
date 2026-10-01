class SignatureModel {
  final String id;
  final String name;
  final String content;
  final bool isDefault;

  const SignatureModel({
    required this.id,
    required this.name,
    required this.content,
    this.isDefault = false,
  });

  factory SignatureModel.fromJson(Map<String, dynamic> json) {
    return SignatureModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Signature',
      content: json['content']?.toString() ?? '',
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'content': content,
        'isDefault': isDefault,
      };

  SignatureModel copyWith({
    String? id,
    String? name,
    String? content,
    bool? isDefault,
  }) {
    return SignatureModel(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
