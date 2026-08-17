import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing global font size state and persisting preference in SharedPreferences.
class FontSizeProvider extends ChangeNotifier {
  static const String _keyFontSize = 'app_font_size';
  static const double defaultFontSize = 16.0;
  static const double minFontSize = 12.0;
  static const double maxFontSize = 19.0;

  double _fontSize = defaultFontSize;

  double get fontSize => _fontSize;

  FontSizeProvider() {
    _loadFontSize();
  }

  /// Loads font size from persistent storage.
  Future<void> _loadFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_keyFontSize)) {
        final val = prefs.getDouble(_keyFontSize);
        if (val != null) {
          _fontSize = val.clamp(minFontSize, maxFontSize);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[FontSizeProvider _loadFontSize Error]: $e');
    }
  }

  /// Updates the global font size and saves to persistent storage.
  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(minFontSize, maxFontSize);
    if (_fontSize == clamped) return;
    _fontSize = clamped;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyFontSize, _fontSize);
    } catch (e) {
      debugPrint('[FontSizeProvider setFontSize Error]: $e');
    }
  }

  /// Resets font size to default (16).
  Future<void> resetToDefault() async {
    await setFontSize(defaultFontSize);
  }
}
