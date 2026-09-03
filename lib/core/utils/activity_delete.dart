import 'package:flutter/foundation.dart';

import '../network/api_constants.dart';
import '../network/api_service.dart';

/// The outcome of deleting a batch of activities.
class ActivityDeleteResult {
  /// Ids the backend confirmed it removed.
  final List<String> deleted;

  /// Ids the backend refused, kept so the caller can leave those records on
  /// screen instead of pretending they are gone.
  final List<String> failed;

  const ActivityDeleteResult({required this.deleted, required this.failed});

  bool get allSucceeded => failed.isEmpty;
}

/// Deletes each id through `DELETE /api/activities/:id`, the endpoint the API
/// documents for tasks, calls, meetings, emails and notes alike.
///
/// Every id is attempted even when an earlier one fails, and the result names
/// which ones actually went; nothing here removes anything locally, so a caller
/// that reloads from the API cannot show a record the backend still holds.
Future<ActivityDeleteResult> deleteActivities(
  Iterable<String> ids, {
  ApiService? apiService,
}) async {
  final api = apiService ?? ApiService();
  final deleted = <String>[];
  final failed = <String>[];

  for (final id in ids) {
    if (id.trim().isEmpty) continue;
    try {
      await api.delete('${ApiConstants.activities}/$id');
      debugPrint('[DELETE ${ApiConstants.activities}/$id] removed');
      deleted.add(id);
    } catch (e) {
      debugPrint('[DELETE ${ApiConstants.activities}/$id ERROR]: $e');
      failed.add(id);
    }
  }

  return ActivityDeleteResult(deleted: deleted, failed: failed);
}
