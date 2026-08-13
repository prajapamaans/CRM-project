/// Model representing a single unified activity item returned from GET /api/activities/dashboard-unified.
class DashboardActivityItem {
  final String id;
  final String? type; // 'call', 'meeting', 'email', 'task', 'note'
  final String? title;
  final String? description;
  final String? status; // 'completed', 'pending', etc.
  final String? dueDate;
  final String? createdAt;
  final String? ownerId;
  final String? ownerName;
  final String? contactId;
  final String? contactName;
  final String? companyId;
  final String? companyName;
  final String? dealId;
  final String? dealName;

  DashboardActivityItem({
    required this.id,
    this.type,
    this.title,
    this.description,
    this.status,
    this.dueDate,
    this.createdAt,
    this.ownerId,
    this.ownerName,
    this.contactId,
    this.contactName,
    this.companyId,
    this.companyName,
    this.dealId,
    this.dealName,
  });

  factory DashboardActivityItem.fromJson(Map<String, dynamic> json) {
    return DashboardActivityItem(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      type: json['type'] as String? ?? json['activityType'] as String? ?? json['activity_type'] as String?,
      title: json['title'] as String? ?? json['subject'] as String? ?? json['name'] as String?,
      description: json['description'] as String? ?? json['notes'] as String? ?? json['body'] as String?,
      status: json['status'] as String?,
      dueDate: json['dueDate'] as String? ?? json['due_date'] as String? ?? json['scheduledAt'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      ownerId: json['ownerId'] as String? ?? json['owner_id'] as String? ?? json['userId'] as String?,
      ownerName: json['ownerName'] as String? ?? json['owner_name'] as String? ?? json['userName'] as String?,
      contactId: json['contactId'] as String? ?? json['contact_id'] as String?,
      contactName: json['contactName'] as String? ?? json['contact_name'] as String?,
      companyId: json['companyId'] as String? ?? json['company_id'] as String?,
      companyName: json['companyName'] as String? ?? json['company_name'] as String?,
      dealId: json['dealId'] as String? ?? json['deal_id'] as String?,
      dealName: json['dealName'] as String? ?? json['deal_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'status': status,
      'dueDate': dueDate,
      'createdAt': createdAt,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'contactId': contactId,
      'companyId': companyName,
      'companyName': companyName,
      'dealId': dealId,
      'dealName': dealName,
    };
  }
}

/// Response wrapper for GET /api/activities/dashboard-unified.
class DashboardUnifiedResponseModel {
  final List<DashboardActivityItem> data;
  final int page;
  final int limit;
  final int total;

  DashboardUnifiedResponseModel({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
  });

  factory DashboardUnifiedResponseModel.fromJson(Map<String, dynamic> json) {
    List<DashboardActivityItem> items = [];

    final rawData = json['data'];
    if (rawData is List) {
      items = rawData
          .map((e) => DashboardActivityItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return DashboardUnifiedResponseModel(
      data: items,
      page: meta['page'] as int? ?? json['page'] as int? ?? 1,
      limit: meta['limit'] as int? ?? json['limit'] as int? ?? items.length,
      total: meta['total'] as int? ?? json['total'] as int? ?? items.length,
    );
  }
}
