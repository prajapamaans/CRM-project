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
    return NotificationModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? json['is_read'] as bool? ?? (json['readAt'] != null || json['read_at'] != null),
      readAt: json['readAt'] as String? ?? json['read_at'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String? ?? '',
      entityType: json['entityType'] as String? ?? json['entity_type'] as String?,
      entityId: json['entityId'] as String? ?? json['entity_id'] as String?,
      activityType: json['activityType'] as String? ?? json['activity_type'] as String?,
      contactId: json['contactId'] as String? ?? json['contact_id'] as String?,
      companyId: json['companyId'] as String? ?? json['company_id'] as String?,
      dealId: json['dealId'] as String? ?? json['deal_id'] as String?,
      contactName: json['contactName'] as String? ?? json['contact_name'] as String?,
      companyName: json['companyName'] as String? ?? json['company_name'] as String?,
      dealName: json['dealName'] as String? ?? json['deal_name'] as String?,
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
