import '../providers/master_data_provider.dart';

/// Shared helpers for every screen that shows an MSP field.
///
/// MSP values always come from `GET /api/msp-options` via [MasterDataProvider];
/// no screen keeps its own list of provider names.
class MspFieldUtils {
  MspFieldUtils._();

  /// Placeholder shown on an MSP dropdown, reflecting the current load state.
  static String placeholder(
    MasterDataProvider provider, {
    String idle = 'Select an MSP',
  }) {
    if (provider.isMspLoading && provider.mspNames.isEmpty) {
      return 'Loading MSPs...';
    }
    if (provider.mspError != null && provider.mspNames.isEmpty) {
      return 'Failed to load MSPs — tap to retry';
    }
    if (provider.mspNames.isEmpty) {
      return 'No MSP options available';
    }
    return idle;
  }

  /// Splits a record's stored MSP field into names. Records hold one or more
  /// MSPs as a comma-separated string (`'Magnit, Beeline'`).
  static List<String> namesFrom(String? stored) {
    final value = stored?.trim();
    if (value == null || value.isEmpty) return const [];
    return value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// The API options, plus any value already stored on the record so an
  /// existing selection is never silently dropped from the field.
  static List<String> optionsWith(
    MasterDataProvider provider,
    String? currentValue,
  ) {
    final options = List<String>.from(provider.mspNames);
    final current = currentValue?.trim();
    if (current != null && current.isNotEmpty && !options.contains(current)) {
      options.add(current);
    }
    return options;
  }
}
