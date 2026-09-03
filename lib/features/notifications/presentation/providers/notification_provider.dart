import 'package:flutter/foundation.dart';
import '../../../../core/network/network_exception.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

enum NotificationState { initial, loading, loaded, error }

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;

  NotificationState _state = NotificationState.initial;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;

  NotificationProvider({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepositoryImpl();

  NotificationState get state => _state;
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications({
    String? companyId,
    String? contactId,
    String? dealId,
    String? createdDateRange,
    String? departmentId,
    int? limit = 50,
  }) async {
    _isLoading = true;
    _state = NotificationState.loading;
    _error = null;
    notifyListeners();

    try {
      _notifications = await _repository.getNotifications(
        companyId: companyId,
        contactId: contactId,
        dealId: dealId,
        createdDateRange: createdDateRange,
        departmentId: departmentId,
        limit: limit,
      );
      _state = NotificationState.loaded;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e is NetworkException ? e.message : 'Failed to fetch notifications.';
      _state = NotificationState.error;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final old = _notifications[index];
        _notifications[index] = NotificationModel(
          id: old.id,
          userId: old.userId,
          type: old.type,
          message: old.message,
          isRead: true,
          readAt: DateTime.now().toIso8601String(),
          createdAt: old.createdAt,
          entityType: old.entityType,
          entityId: old.entityId,
          activityType: old.activityType,
          contactId: old.contactId,
          companyId: old.companyId,
          dealId: old.dealId,
          contactName: old.contactName,
          companyName: old.companyName,
          dealName: old.dealName,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
      _notifications = _notifications.map((n) {
        return NotificationModel(
          id: n.id,
          userId: n.userId,
          type: n.type,
          message: n.message,
          isRead: true,
          readAt: DateTime.now().toIso8601String(),
          createdAt: n.createdAt,
          entityType: n.entityType,
          entityId: n.entityId,
          activityType: n.activityType,
          contactId: n.contactId,
          companyId: n.companyId,
          dealId: n.dealId,
          contactName: n.contactName,
          companyName: n.companyName,
          dealName: n.dealName,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Deletes notification by ID via DELETE /api/activities/notifications/:id
  /// and removes it from the local provider list upon success.
  Future<void> deleteNotification(String notificationId) async {
    await _repository.deleteNotification(notificationId);
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// Drops everything held for the previous department.
  ///
  /// Notifications are department-scoped, so they must not survive a switch —
  /// including the unread badge, which is counted from this list.
  void clearData() {
    _notifications = [];
    _state = NotificationState.initial;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
