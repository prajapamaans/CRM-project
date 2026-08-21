import 'dart:convert';

/// Helper utility to parse activity descriptions, notes, and rich-text JSON payloads
/// (e.g. TipTap / ProseMirror `{"type":"doc","content":[...]}` format or HTML) into clean human-readable text.
class ActivityTextParser {
  ActivityTextParser._();

  static String parse(dynamic val) {
    if (val == null) return '';

    if (val is Map || val is List) {
      final extracted = _extractTextFromRichJson(val).trim();
      if (extracted.isNotEmpty) return extracted;
    }

    String str = val.toString().trim();
    if (str.isEmpty) return '';

    // Check if JSON formatted string
    if ((str.startsWith('{') && str.endsWith('}')) ||
        (str.startsWith('[') && str.endsWith(']'))) {
      try {
        final decoded = jsonDecode(str);
        final extracted = _extractTextFromRichJson(decoded).trim();
        if (extracted.isNotEmpty) return extracted;
      } catch (_) {}
    }

    // Strip HTML tags if string contains HTML elements
    if (str.contains('<') && str.contains('>')) {
      str = str.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return str;
  }

  static String _extractTextFromRichJson(dynamic node) {
    if (node is Map) {
      if (node.containsKey('text') && node['text'] != null) {
        return node['text'].toString();
      }
      final List<String> parts = [];
      if (node.containsKey('content') && node['content'] is List) {
        for (final child in node['content']) {
          final text = _extractTextFromRichJson(child).trim();
          if (text.isNotEmpty) parts.add(text);
        }
      }
      if (node.containsKey('children') && node['children'] is List) {
        for (final child in node['children']) {
          final text = _extractTextFromRichJson(child).trim();
          if (text.isNotEmpty) parts.add(text);
        }
      }
      return parts.join('\n');
    } else if (node is List) {
      final List<String> parts = [];
      for (final item in node) {
        final text = _extractTextFromRichJson(item).trim();
        if (text.isNotEmpty) parts.add(text);
      }
      return parts.join('\n');
    }
    return node?.toString() ?? '';
  }
}
