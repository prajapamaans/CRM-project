import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper utility for persisting locally created activities across app refreshes and restarts.
class LocalActivitiesStorage {
  static const String _keyLocalActivities = 'local_created_activities';

  /// Retrieves persistent local activities for a specific entity (contactId, companyId, dealId).
  static Future<List<Map<String, dynamic>>> getLocalActivities(String entityId) async {
    if (entityId.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('${_keyLocalActivities}_$entityId');
      if (jsonString != null && jsonString.isNotEmpty) {
        final List list = jsonDecode(jsonString);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[LocalActivitiesStorage getLocalActivities ERROR]: $e');
    }
    return [];
  }

  /// Saves a locally created activity persistently.
  static Future<void> saveLocalActivity(String entityId, Map<String, dynamic> activity) async {
    if (entityId.isEmpty) return;
    try {
      final existing = await getLocalActivities(entityId);
      final actId = activity['id']?.toString();
      if (actId != null && actId.isNotEmpty) {
        existing.removeWhere((item) => item['id']?.toString() == actId);
      }
      existing.insert(0, activity);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_keyLocalActivities}_$entityId', jsonEncode(existing));
    } catch (e) {
      debugPrint('[LocalActivitiesStorage saveLocalActivity ERROR]: $e');
    }
  }
}
