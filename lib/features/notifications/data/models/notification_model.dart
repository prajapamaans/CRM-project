/// Model representing a notification item returned from GET /api/activities/notifications.
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String message;
  final bool isRead;
  final String? readAt;
  final String createdAt;
  final String? entityType;
  final String? entityId;
  final String? activityType;
  final String? contactId;
  final String? companyId;
  final String? dealId;
  final String? contactName;
  final String? companyName;
  final String? dealName;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    this.entityType,
    this.entityId,
    this.activityType,
    this.contactId,
    this.companyId,
    this.dealId,
    this.contactName,
    this.companyName,
    this.dealName,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    String? extractContactName(dynamic contact) {
      if (contact is Map) {
        if (contact['name'] != null && contact['name'].toString().isNotEmpty) {
          return contact['name'].toString();
        }
        final fn = contact['firstName'] ?? contact['first_name'] ?? '';
        final ln = contact['lastName'] ?? contact['last_name'] ?? '';
        final name = '$fn $ln'.trim();
        if (name.isNotEmpty) return name;
      }
      return null;
    }

    String? extractCompanyName(dynamic company) {
      if (company is Map && company['name'] != null) {
        return company['name'].toString();
      }
      return null;
    }

    String? extractDealName(dynamic deal) {
      if (deal is Map) {
        if (deal['name'] != null) return deal['name'].toString();
        if (deal['title'] != null) return deal['title'].toString();
      }
      return null;
    }

    return NotificationModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? json['recipientId']?.toString() ?? '',
      type: json['type']?.toString() ?? json['notificationType']?.toString() ?? json['eventType']?.toString() ?? '',
      message: json['message']?.toString() ?? json['content']?.toString() ?? json['description']?.toString() ?? json['title']?.toString() ?? '',
      isRead: json['isRead'] as bool? ?? json['is_read'] as bool? ?? json['read'] as bool? ?? (json['readAt'] != null || json['read_at'] != null),
      readAt: json['readAt']?.toString() ?? json['read_at']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? json['timestamp']?.toString() ?? '',
      entityType: json['entityType']?.toString() ?? json['entity_type']?.toString() ?? json['targetType']?.toString(),
      entityId: json['entityId']?.toString() ?? json['entity_id']?.toString() ?? json['targetId']?.toString(),
      activityType: json['activityType']?.toString() ?? json['activity_type']?.toString(),
      contactId: json['contactId']?.toString() ?? json['contact_id']?.toString() ?? (json['contact'] is Map ? json['contact']['id']?.toString() : null),
      companyId: json['companyId']?.toString() ?? json['company_id']?.toString() ?? (json['company'] is Map ? json['company']['id']?.toString() : null),
      dealId: json['dealId']?.toString() ?? json['deal_id']?.toString() ?? (json['deal'] is Map ? json['deal']['id']?.toString() : null),
      contactName: json['contactName']?.toString() ?? json['contact_name']?.toString() ?? extractContactName(json['contact']),
      companyName: json['companyName']?.toString() ?? json['company_name']?.toString() ?? extractCompanyName(json['company']),
      dealName: json['dealName']?.toString() ?? json['deal_name']?.toString() ?? extractDealName(json['deal']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'message': message,
      'isRead': isRead,
      'readAt': readAt,
      'createdAt': createdAt,
      'entityType': entityType,
      'entityId': entityId,
      'activityType': activityType,
      'contactId': contactId,
      'companyId': companyId,
      'dealId': dealId,
      'contactName': contactName,
      'companyName': companyName,
      'dealName': dealName,
    };
  }
}
