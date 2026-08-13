import '../../../../../../core/network/api_constants.dart';
import '../../../../../../core/network/api_service.dart';
import '../../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<List<NotificationModel>> getNotifications({
    String? companyId,
    String? contactId,
    String? dealId,
    String? createdDateRange,
    int? limit,
  });

  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
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
    int? limit,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (companyId != null) queryParameters['companyId'] = companyId;
    if (contactId != null) queryParameters['contactId'] = contactId;
    if (dealId != null) queryParameters['dealId'] = dealId;
    if (createdDateRange != null) queryParameters['createdDateRange'] = createdDateRange;
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
      if (rawData.containsKey('data') && rawData['data'] is List) {
        list = rawData['data'] as List<dynamic>;
      } else if (rawData.containsKey('notifications') && rawData['notifications'] is List) {
        list = rawData['notifications'] as List<dynamic>;
      }
    }

    return list
        .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
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
}
