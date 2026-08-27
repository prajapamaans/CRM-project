import '../../../../../../core/network/api_constants.dart';
import '../../../../../../core/network/api_service.dart';
import '../../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<List<NotificationModel>> getNotifications({
    String? companyId,
    String? contactId,
    String? dealId,
    String? createdDateRange,
    String? departmentId,
    int? limit,
  });

  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String notificationId);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final ApiService _apiService;

  NotificationRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<List<NotificationModel>> getNotifications({
    String? companyId,
    String? contactId,
    String? dealId,
    String? createdDateRange,
    String? departmentId,
    int? limit,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (companyId != null && companyId.isNotEmpty) queryParameters['companyId'] = companyId;
    if (contactId != null && contactId.isNotEmpty) queryParameters['contactId'] = contactId;
    if (dealId != null && dealId.isNotEmpty) queryParameters['dealId'] = dealId;
    if (createdDateRange != null && createdDateRange.isNotEmpty) queryParameters['createdDateRange'] = createdDateRange;
    if (departmentId != null && departmentId.isNotEmpty) queryParameters['department_id'] = departmentId;
    if (limit != null) queryParameters['limit'] = limit;

    final response = await _apiService.get(
      ApiConstants.notifications,
      queryParameters: queryParameters,
    );

    final dynamic rawData = response.data;
    List<dynamic> list = [];

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic>) {
      final dataField = rawData['data'] ?? rawData['notifications'] ?? rawData['items'] ?? rawData['results'];
      if (dataField is List) {
        list = dataField;
      } else if (dataField is Map<String, dynamic>) {
        final innerList = dataField['data'] ?? dataField['items'] ?? dataField['notifications'];
        if (innerList is List) list = innerList;
      }
    }

    return list
        .whereType<Map>()
        .map((item) => NotificationModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _apiService.patch('${ApiConstants.notifications}/$notificationId/read');
  }

  @override
  Future<void> markAllAsRead() async {
    await _apiService.patch('${ApiConstants.notifications}/mark-all-read');
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await _apiService.delete('${ApiConstants.notifications}/$notificationId');
  }
}
