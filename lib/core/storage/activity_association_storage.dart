import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';

/// Centralized manager for persistent activity associations across refreshes and app restarts.
class ActivityAssociationStorage {
  static final Map<String, Map<String, List<Map<String, String>>>> _memoryCache = {};
  static final SecureStorageService _storage = SecureStorageService();

  /// Key format for storage
  static String _key(String actId) => 'act_assoc_$actId';

  /// Save associations for a specific activity ID to memory cache and secure storage.
  static Future<void> saveAssociations(
    String actId,
    Map<String, List<Map<String, String>>> associations,
  ) async {
    if (actId.isEmpty) return;

    // Clean nulls and duplicates
    final Map<String, List<Map<String, String>>> clean = {
      'Companies': [],
      'Contacts': [],
      'Deals': [],
    };

    for (final key in ['Companies', 'Contacts', 'Deals']) {
      final list = associations[key];
      if (list != null) {
        for (final item in list) {
          final id = item['id']?.toString();
          final name = item['name']?.toString() ?? key.substring(0, key.length - 1);
          if (id != null && id.isNotEmpty) {
            if (!clean[key]!.any((x) => x['id'] == id)) {
              clean[key]!.add({'id': id, 'name': name});
            }
          }
        }
      }
    }

    _memoryCache[actId] = clean;

    try {
      final jsonStr = jsonEncode(clean);
      await _storage.saveString(_key(actId), jsonStr);
    } catch (e) {
      debugPrint('[ActivityAssociationStorage save error]: $e');
    }
  }

  /// Synchronously get cached associations from memory (or return null if not loaded yet).
  static Map<String, List<Map<String, String>>>? getMemoryAssociations(String actId) {
    return _memoryCache[actId];
  }

  /// Asynchronously retrieve associations from storage for an activity ID.
  static Future<Map<String, List<Map<String, String>>>> getAssociations(String actId) async {
    if (actId.isEmpty) {
      return {'Companies': [], 'Contacts': [], 'Deals': []};
    }

    if (_memoryCache.containsKey(actId)) {
      return _memoryCache[actId]!;
    }

    try {
      final jsonStr = await _storage.getString(_key(actId));
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          final Map<String, List<Map<String, String>>> loaded = {
            'Companies': [],
            'Contacts': [],
            'Deals': [],
          };

          for (final key in ['Companies', 'Contacts', 'Deals']) {
            final list = decoded[key];
            if (list is List) {
              for (final item in list) {
                if (item is Map) {
                  final id = item['id']?.toString();
                  final name = item['name']?.toString() ?? key.substring(0, key.length - 1);
                  if (id != null && id.isNotEmpty) {
                    if (!loaded[key]!.any((x) => x['id'] == id)) {
                      loaded[key]!.add({'id': id, 'name': name});
                    }
                  }
                }
              }
            }
          }

          _memoryCache[actId] = loaded;
          return loaded;
        }
      }
    } catch (e) {
      debugPrint('[ActivityAssociationStorage load error]: $e');
    }

    return {'Companies': [], 'Contacts': [], 'Deals': []};
  }

  /// Merges persisted associations into the extracted associations map for an activity.
  static Map<String, List<Map<String, String>>> mergeAssociations(
    Map<String, dynamic> act,
    Map<String, List<Map<String, String>>> extracted,
  ) {
    final actId = (act['id'] ?? act['_id'])?.toString();
    final Map<String, List<Map<String, String>>> merged = {
      'Companies': List.from(extracted['Companies'] ?? []),
      'Contacts': List.from(extracted['Contacts'] ?? []),
      'Deals': List.from(extracted['Deals'] ?? []),
    };

    if (actId != null && actId.isNotEmpty) {
      final cached = _memoryCache[actId];
      if (cached != null) {
        for (final key in ['Companies', 'Contacts', 'Deals']) {
          final list = cached[key];
          if (list != null) {
            for (final item in list) {
              final id = item['id'];
              if (id != null && id.isNotEmpty) {
                if (!merged[key]!.any((x) => x['id'] == id)) {
                  merged[key]!.add({'id': id, 'name': item['name'] ?? key.substring(0, key.length - 1)});
                }
              }
            }
          }
        }
      }
    }

    return merged;
  }

  /// Helper to check if an activity is associated with a given entity (Contact, Company, or Deal).
  static bool isAssociatedWithEntity(
    Map<String, dynamic> act,
    String entityType, // 'contact', 'company', or 'deal'
    String entityId,
  ) {
    if (entityId.isEmpty) return false;

    // Check direct fields
    if (entityType.toLowerCase() == 'contact') {
      final cntId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null))?.toString();
      if (cntId == entityId) return true;
    } else if (entityType.toLowerCase() == 'company') {
      final compId = (act['companyId'] ?? act['company_id'] ?? (act['company'] is Map ? act['company']['id'] : null))?.toString();
      if (compId == entityId) return true;
    } else if (entityType.toLowerCase() == 'deal') {
      final dId = (act['dealId'] ?? act['deal_id'] ?? (act['deal'] is Map ? act['deal']['id'] : null))?.toString();
      if (dId == entityId) return true;
    }

    final actId = (act['id'] ?? act['_id'])?.toString();
    if (actId != null && actId.isNotEmpty) {
      final cached = _memoryCache[actId];
      if (cached != null) {
        final category = entityType.toLowerCase() == 'contact'
            ? 'Contacts'
            : entityType.toLowerCase() == 'company'
                ? 'Companies'
                : 'Deals';
        final list = cached[category];
        if (list != null && list.any((x) => x['id'] == entityId)) {
          return true;
        }
      }
    }

    return false;
  }
}
