/// Builds the query for `GET /api/activities` when it is being used as the
/// task list, and decides whether a response that comes back is still wanted.
library;

import 'department_scope.dart';

/// The query the Tasks screen sends.
///
/// `type=task` and the selected department are always part of it — the list is
/// department-specific at the request, not trimmed down afterwards. Empty
/// values are left out entirely: a blank `search=` or `status=` reads to some
/// backends as a filter that matches nothing.
Map<String, dynamic> buildTaskListQuery({
  required int page,
  required int limit,
  required String departmentId,
  String sort = 'createdAt',
  String order = 'desc',
  String? search,
  String? status,
  String? priority,
  String? ownerId,
  String? companyId,
  String? contactId,
  String? dealId,
  String? createdDateRange,
}) {
  final query = <String, dynamic>{
    'page': page,
    'limit': limit,
    'sort': sort,
    'order': order,
    'type': 'task',
  };

  void put(String key, String? value) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) query[key] = trimmed;
  }

  // Both spellings, matching every other department-scoped call in this app.
  // `AuthInterceptor` puts the same id on the request headers.
  query.addAll(departmentQuery(departmentId));

  put('search', search);
  put('status', status);
  put('priority', priority);
  put('ownerId', ownerId);
  put('companyId', companyId);
  put('contactId', contactId);
  put('dealId', dealId);
  put('createdDateRange', createdDateRange);

  return query;
}

/// Whether a response may be written into the list.
///
/// It may not if a newer request has since gone out, or if the department it
/// was asked for is no longer the selected one — either would put another
/// department's tasks on screen.
bool shouldApplyTaskResponse({
  required int responseSeq,
  required int latestSeq,
  required String requestedDepartmentId,
  required String selectedDepartmentId,
}) {
  // One rule, shared with the Dashboard, so the two cannot disagree about
  // whose response is still wanted.
  return mayApplyDepartmentResponse(
    responseSeq: responseSeq,
    latestSeq: latestSeq,
    requestedDepartmentId: requestedDepartmentId,
    selectedDepartmentId: selectedDepartmentId,
  );
}
