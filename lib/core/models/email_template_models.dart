class EmailTemplateFolder {
  final String id;
  final String name;
  final String? parentId;
  final String? createdAt;
  final String? updatedAt;
  final String? createdBy;
  final String? ownerName;

  const EmailTemplateFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.ownerName,
  });

  factory EmailTemplateFolder.fromJson(Map<String, dynamic> json) {
    return EmailTemplateFolder(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? 'Folder').toString(),
      parentId: json['parentId']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      createdBy: json['createdBy']?.toString(),
      ownerName: json['ownerName']?.toString() ?? json['owner']?.toString() ?? 'Admin User',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'ownerName': ownerName,
    };
  }
}

class EmailTemplate {
  final String? id;
  final String name;
  final String subject;
  final String body;
  final String sharedSetting;
  final String? folderId;
  final String? createdAt;
  final String? updatedAt;
  final String? createdBy;
  final String ownerName;

  const EmailTemplate({
    this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.sharedSetting = 'private',
    this.folderId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.ownerName = 'Admin User',
  });

  factory EmailTemplate.fromJson(Map<String, dynamic> json) {
    return EmailTemplate(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      name: (json['name'] ?? json['title'] ?? 'Template').toString(),
      subject: (json['subject'] ?? '').toString(),
      body: (json['body'] ?? json['content'] ?? '').toString(),
      sharedSetting: (json['sharedSetting'] ?? json['privacy'] ?? 'private').toString(),
      folderId: json['folderId']?.toString() ?? json['folder']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      createdBy: json['createdBy']?.toString(),
      ownerName: json['ownerName']?.toString() ?? json['owner']?.toString() ?? 'Admin User',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'subject': subject,
      'body': body,
      'sharedSetting': sharedSetting,
      'folderId': folderId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'ownerName': ownerName,
    };
  }

  EmailTemplate copyWith({
    String? id,
    String? name,
    String? subject,
    String? body,
    String? sharedSetting,
    String? folderId,
    String? createdAt,
    String? updatedAt,
    String? createdBy,
    String? ownerName,
  }) {
    return EmailTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      sharedSetting: sharedSetting ?? this.sharedSetting,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      ownerName: ownerName ?? this.ownerName,
    );
  }
}

class EmailTemplatesResponse {
  final bool success;
  final List<EmailTemplateFolder> folders;
  final List<EmailTemplate> templates;
  final List<dynamic> path;

  const EmailTemplatesResponse({
    required this.success,
    required this.folders,
    required this.templates,
    required this.path,
  });

  factory EmailTemplatesResponse.fromJson(Map<String, dynamic> json) {
    final rawFolders = json['folders'];
    final rawTemplates = json['templates'];
    final rawPath = json['path'];

    return EmailTemplatesResponse(
      success: json['success'] == true || json['status'] == 'success' || json['success'] == 'true',
      folders: (rawFolders is List)
          ? rawFolders
              .whereType<Map<String, dynamic>>()
              .map((e) => EmailTemplateFolder.fromJson(e))
              .toList()
          : [],
      templates: (rawTemplates is List)
          ? rawTemplates
              .whereType<Map<String, dynamic>>()
              .map((e) => EmailTemplate.fromJson(e))
              .toList()
          : [],
      path: (rawPath is List) ? rawPath : [],
    );
  }
}
