import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/network/network_exception.dart';
import '../datasource/remote/notification_remote_datasource.dart';
import '../models/notification_model.dart';

abstract class NotificationRepository {
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

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationRepositoryImpl({NotificationRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? NotificationRemoteDataSourceImpl();

  @override
  Future<List<NotificationModel>> getNotifications({
    String? companyId,
    String? contactId,
    String? dealId,
    String? createdDateRange,
    String? departmentId,
    int? limit,
  }) async {
    try {
      final notifications = await _remoteDataSource.getNotifications(
        companyId: companyId,
        contactId: contactId,
        dealId: dealId,
        createdDateRange: createdDateRange,
        departmentId: departmentId,
        limit: limit,
      );

      // Print complete Notifications API Response during testing
      debugPrint('==================================================');
      debugPrint('[NOTIFICATIONS API RESPONSE] Count: ${notifications.length}');
      for (int i = 0; i < notifications.length; i++) {
        debugPrint('[NOTIFICATION #$i] ${jsonEncode(notifications[i].toJson())}');
      }
      debugPrint('==================================================');

      return notifications;
    } on NetworkException catch (e) {
      debugPrint('[NOTIFICATIONS API ERROR] NetworkException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[NOTIFICATIONS API ERROR] Unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _remoteDataSource.markAsRead(notificationId);
      debugPrint('[NOTIFICATIONS API SUCCESS] Marked notification $notificationId as read');
    } catch (e) {
      debugPrint('[NOTIFICATIONS API ERROR] Failed to mark as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await _remoteDataSource.markAllAsRead();
      debugPrint('[NOTIFICATIONS API SUCCESS] Marked all notifications as read');
    } catch (e) {
      debugPrint('[NOTIFICATIONS API ERROR] Failed to mark all as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _remoteDataSource.deleteNotification(notificationId);
      debugPrint('[NOTIFICATIONS API SUCCESS] Deleted notification $notificationId via DELETE /api/activities/notifications/$notificationId');
    } catch (e) {
      debugPrint('[NOTIFICATIONS API ERROR] Failed to delete notification $notificationId: $e');
      rethrow;
    }
  }
}
