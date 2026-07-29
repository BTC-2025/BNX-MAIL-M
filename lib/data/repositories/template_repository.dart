import '../../core/network/api_client.dart';
import '../../core/network/token_service.dart';

class TemplateModel {
  final String id;
  final String title;
  final String category;
  final String type; // 'DEFAULT' or 'CUSTOM'
  final String subject;
  final String body;

  const TemplateModel({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.subject,
    required this.body,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    final titleVal = json['title']?.toString() ?? json['name']?.toString();
    final bodyVal = json['body']?.toString() ?? json['content']?.toString();
    return TemplateModel(
      id: json['id']?.toString() ?? '',
      title: (titleVal != null && titleVal.isNotEmpty) ? titleVal : 'Custom Template',
      category: json['category']?.toString() ?? 'Personal',
      type: json['type']?.toString() ?? 'CUSTOM',
      subject: json['subject']?.toString() ?? '',
      body: (bodyVal != null) ? bodyVal : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'name': title,
        'category': category,
        'type': type,
        'subject': subject,
        'body': body,
        'content': body,
      };
}

class TemplateRepository {
  /// GET /api/templates?userEmail={email}
  static Future<List<TemplateModel>> getTemplates(String userEmail) async {
    final email = userEmail.isNotEmpty ? userEmail : (await TokenService.getUserEmail() ?? '');
    final localMaps = await TokenService.getUserTemplates(email);
    final localModels = localMaps.map((m) => TemplateModel.fromJson(m)).toList();

    try {
      final queryParams = email.isNotEmpty ? {'userEmail': email} : null;
      final res = await ApiClient.get('/api/templates', queryParams: queryParams);
      final rawList = res['data'] ?? res['templates'] ?? res['content'] ?? res;

      if (rawList is List) {
        final remoteModels = rawList
            .whereType<Map<String, dynamic>>()
            .map((json) => TemplateModel.fromJson(json))
            .toList();

        final Map<String, TemplateModel> mergedMap = {};
        for (final m in localModels) {
          mergedMap[m.id] = m;
        }
        for (final m in remoteModels) {
          mergedMap[m.id] = m;
        }
        final mergedList = mergedMap.values.toList();
        if (email.isNotEmpty) {
          await TokenService.saveUserTemplates(email, mergedList.map((e) => e.toJson()).toList());
        }
        return mergedList;
      }
    } catch (e) {
      print('[TEMPLATES API LOG] Fetch error: $e');
    }
    return localModels;
  }

  /// POST /api/templates?userEmail={email}
  static Future<TemplateModel?> createTemplate(
    String userEmail, {
    required String name,
    required String subject,
    required String content,
    String category = 'Personal',
  }) async {
    final email = userEmail.isNotEmpty ? userEmail : (await TokenService.getUserEmail() ?? '');
    TemplateModel? result;

    try {
      final queryParams = email.isNotEmpty ? {'userEmail': email} : null;
      final body = {
        'title': name,
        'name': name,
        'subject': subject,
        'body': content,
        'content': content,
        'category': category,
        'isDefault': false,
      };

      final res = await ApiClient.post(
        '/api/templates',
        queryParams: queryParams,
        body: body,
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? (res);
      if (data.isNotEmpty) {
        result = TemplateModel.fromJson(data);
      }
    } catch (e) {
      print('[TEMPLATES API LOG] Create error: $e');
    }

    result ??= TemplateModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: name,
      category: category,
      type: 'CUSTOM',
      subject: subject,
      body: content,
    );

    if (email.isNotEmpty) {
      final existing = await TokenService.getUserTemplates(email);
      existing.add(result.toJson());
      await TokenService.saveUserTemplates(email, existing);
    }

    return result;
  }

  /// PUT /api/templates/{id}?userEmail={email}
  static Future<void> updateTemplate(
    String id,
    String userEmail, {
    required String name,
    required String subject,
    required String content,
    String category = 'Personal',
  }) async {
    try {
      final email = userEmail.isNotEmpty ? userEmail : (await TokenService.getUserEmail() ?? '');
      final body = {
        'title': name,
        'name': name,
        'subject': subject,
        'body': content,
        'content': content,
        'category': category,
        'isDefault': false,
      };
      final path = email.isNotEmpty
          ? '/api/templates/$id?userEmail=${Uri.encodeComponent(email)}'
          : '/api/templates/$id';
      await ApiClient.put(path, body: body);
    } catch (e) {
      print('[TEMPLATES API LOG] Update error: $e');
    }
  }

  /// DELETE /api/templates/{id}?userEmail={email}
  static Future<void> deleteTemplate(String id, String userEmail) async {
    final email = userEmail.isNotEmpty ? userEmail : (await TokenService.getUserEmail() ?? '');
    if (email.isNotEmpty) {
      final existing = await TokenService.getUserTemplates(email);
      existing.removeWhere((item) => item['id']?.toString() == id);
      await TokenService.saveUserTemplates(email, existing);
    }

    try {
      final path = email.isNotEmpty
          ? '/api/templates/$id?userEmail=${Uri.encodeComponent(email)}'
          : '/api/templates/$id';
      await ApiClient.delete(path);
    } catch (e) {
      print('[TEMPLATES API LOG] Delete error: $e');
    }
  }
}
