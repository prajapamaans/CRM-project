import 'dart:convert';

/// Parses raw activity description or notes strings (including TipTap JSON,
/// Quill Delta JSON, or raw plain text) into clean, bracket-free text.
String parseActivityDescription(dynamic rawDescription) {
  if (rawDescription == null) return '';
  String str = rawDescription.toString().trim();
  if (str.isEmpty) return '';

  if (str.startsWith('{') && str.endsWith('}')) {
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) {
        // 1. TipTap / ProseMirror schema: {"type":"doc", "content":[...]}
        if (decoded.containsKey('content') && decoded['content'] is List) {
          final StringBuffer sb = StringBuffer();
          void extractText(dynamic node) {
            if (node is Map<String, dynamic>) {
              if (node.containsKey('text') && node['text'] != null) {
                sb.write(node['text']);
              }
              if (node.containsKey('content') && node['content'] is List) {
                for (var child in node['content']) {
                  extractText(child);
                }
              }
            }
          }
          for (var item in (decoded['content'] as List)) {
            extractText(item);
          }
          final result = sb.toString().trim();
          if (result.isNotEmpty) return result;
        }

        // 2. Quill Delta schema: {"ops":[{"insert":"..."}]}
        if (decoded.containsKey('ops') && decoded['ops'] is List) {
          final StringBuffer sb = StringBuffer();
          for (var op in (decoded['ops'] as List)) {
            if (op is Map && op.containsKey('insert')) {
              sb.write(op['insert']);
            }
          }
          final result = sb.toString().trim();
          if (result.isNotEmpty) return result;
        }

        if (decoded.containsKey('text') && decoded['text'] != null) {
          return decoded['text'].toString().trim();
        }
        if (decoded.containsKey('notes')) {
          return parseActivityDescription(decoded['notes']);
        }
        if (decoded.containsKey('description')) {
          return parseActivityDescription(decoded['description']);
        }
        if (decoded.containsKey('body')) {
          return parseActivityDescription(decoded['body']);
        }
      }
    } catch (_) {}
  }
  return str;
}
