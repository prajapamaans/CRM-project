import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'secure_storage_service.dart';

/// Remembers which task a follow-up came out of.
///
/// The activities API has no parent field, so the link is written to the
/// server as a tag (see `followUpTag`) and mirrored here. This copy is what
/// makes the chain readable straight away and on the next launch; it is a
/// cache of a link, never a substitute for the tasks themselves, which only
/// ever exist on the backend.
class FollowUpLinkStorage {
  static final SecureStorageService _storage = SecureStorageService();

  static final Map<String, List<String>> _childrenCache = {};
  static final Map<String, String> _parentCache = {};

  static String _childrenKey(String taskId) => 'task_follow_ups_$taskId';
  static String _parentKey(String taskId) => 'task_follow_up_parent_$taskId';

  /// Records that [followUpTaskId] follows up on [originalTaskId]. Recording
  /// the same pair twice leaves one link, so a retried write cannot double it.
  static Future<void> link({
    required String originalTaskId,
    required String followUpTaskId,
  }) async {
    if (originalTaskId.isEmpty || followUpTaskId.isEmpty) return;
    if (originalTaskId == followUpTaskId) return;

    final children = await followUpIdsFor(originalTaskId);
    if (!children.contains(followUpTaskId)) {
      children.add(followUpTaskId);
      _childrenCache[originalTaskId] = children;
      await _write(_childrenKey(originalTaskId), jsonEncode(children));
    }

    _parentCache[followUpTaskId] = originalTaskId;
    await _write(_parentKey(followUpTaskId), originalTaskId);
  }

  /// The follow-ups created from [taskId], oldest link first.
  static Future<List<String>> followUpIdsFor(String taskId) async {
    if (taskId.isEmpty) return [];

    final cached = _childrenCache[taskId];
    if (cached != null) return List<String>.from(cached);

    try {
      final raw = await _storage.getString(_childrenKey(taskId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final ids = decoded
              .map((id) => id.toString())
              .where((id) => id.isNotEmpty)
              .toList();
          _childrenCache[taskId] = ids;
          return List<String>.from(ids);
        }
      }
    } catch (e) {
      debugPrint('[FollowUpLinkStorage read error]: $e');
    }

    return [];
  }

  /// The task [followUpTaskId] follows up on, or null when it is not one.
  static Future<String?> originalIdFor(String followUpTaskId) async {
    if (followUpTaskId.isEmpty) return null;

    final cached = _parentCache[followUpTaskId];
    if (cached != null) return cached;

    try {
      final stored = await _storage.getString(_parentKey(followUpTaskId));
      if (stored != null && stored.isNotEmpty) {
        _parentCache[followUpTaskId] = stored;
        return stored;
      }
    } catch (e) {
      debugPrint('[FollowUpLinkStorage read error]: $e');
    }

    return null;
  }

  static Future<void> _write(String key, String value) async {
    try {
      await _storage.saveString(key, value);
    } catch (e) {
      debugPrint('[FollowUpLinkStorage write error]: $e');
    }
  }

  /// Drops the in-memory copy. For tests.
  @visibleForTesting
  static void clearCache() {
    _childrenCache.clear();
    _parentCache.clear();
  }
}
