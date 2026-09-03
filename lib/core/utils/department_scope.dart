/// Which department a request belongs to, and how it says so.
///
/// Every department-scoped call in this app names the department the same two
/// ways — `departmentId` and `department_id` — and `AuthInterceptor` puts the
/// same id on the headers. This library is the one place that decides which id
/// that is and writes the pair, so no screen has to reach for a literal.
library;

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty || trimmed == 'null' ? null : trimmed;
}

/// The department the signed-in user is working in right now.
///
/// [selected] is the department they picked, and wins whenever there is one.
/// Where they have not picked — a fresh install, or a session restored before
/// the picker has loaded — it falls back to the department their own account
/// carries, then to the one they are assigned to.
///
/// Answers with an empty string when none of those is known. That is the
/// honest answer, and it is also the safe one: the request then names no
/// department at all and the API files it under the department baked into the
/// access token, rather than under whichever department happened to be first
/// in a constants file.
String resolveActiveDepartmentId({
  String? selected,
  String? userDepartmentId,
  String? assignedDepartmentId,
}) {
  return _clean(selected) ??
      _clean(userDepartmentId) ??
      _clean(assignedDepartmentId) ??
      '';
}

/// The `departmentId` / `department_id` pair for [departmentId], or nothing at
/// all when it is empty — a blank department reads to the backend as a filter
/// that matches nothing, which is worse than not asking.
Map<String, dynamic> departmentQuery(String? departmentId) {
  final id = _clean(departmentId);
  if (id == null) return const {};
  return {'departmentId': id, 'department_id': id};
}

/// Whether a response that has just arrived may still be written into state.
///
/// It may not if a newer request for the same data has since gone out, or if
/// the department it was asked for is no longer the one selected. Either would
/// put one department's records on a screen labelled with another's.
bool mayApplyDepartmentResponse({
  required int responseSeq,
  required int latestSeq,
  required String requestedDepartmentId,
  required String selectedDepartmentId,
}) {
  if (responseSeq != latestSeq) return false;
  return requestedDepartmentId == selectedDepartmentId;
}

/// Keeps track of which department each in-flight request was issued for, so a
/// slow answer for the department the user has just left cannot land on top of
/// the one they are looking at now.
///
/// Requests are grouped by [key] — one per thing being fetched — so a reload of
/// one section does not invalidate another section's request that is still in
/// the air. The department, though, is shared: the moment a request goes out
/// for a new department, every older department's answers stop being welcome.
class DepartmentRequestGuard {
  String _activeDepartmentId = '';
  final Map<String, int> _issued = {};

  /// The department the most recent request was issued for.
  String get activeDepartmentId => _activeDepartmentId;

  /// Opens a request for [key] against [departmentId] and returns the ticket
  /// that identifies it. Anything issued for this key before now is stale.
  int begin(String key, String? departmentId) {
    _activeDepartmentId = _clean(departmentId) ?? '';
    return _issued[key] = (_issued[key] ?? 0) + 1;
  }

  /// Whether the answer to the request that took [ticket] is still wanted.
  bool mayApply(String key, int ticket, String? departmentId) {
    return mayApplyDepartmentResponse(
      responseSeq: ticket,
      latestSeq: _issued[key] ?? 0,
      requestedDepartmentId: _clean(departmentId) ?? '',
      selectedDepartmentId: _activeDepartmentId,
    );
  }

  /// Abandons every request in the air. Used when cached data is dropped, so
  /// nothing already requested can repopulate what was just cleared.
  void abandonAll() {
    for (final key in _issued.keys.toList()) {
      _issued[key] = (_issued[key] ?? 0) + 1;
    }
  }
}
