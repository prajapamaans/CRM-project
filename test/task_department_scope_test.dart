import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/utils/activity_task_fields.dart';
import 'package:crmproject/core/utils/task_query_builder.dart';
import 'package:crmproject/features/departments/presentation/providers/department_provider.dart';

// The two departments the app ships with, read from the app's own constants
// rather than written out here.
final apacId = DepartmentConstants.apacId;
final australiaId = DepartmentConstants.australiaId;

/// A row exactly as `GET /api/activities?type=task` returns it.
const _apiRow = {
  'id': '79b59358-4aa1-492f-a94f-257c662f856e',
  'organizationId': '2570be88-821b-43af-92a9-3aced45f8fcd',
  'ownerId': '311fee58-ba54-42b9-8795-f3ba19255b20',
  'type': 'task',
  'title': 'hwfu',
  'description': 'Follow up on the renewal',
  'status': 'pending',
  'priority': 'none',
  'scheduledAt': '2026-09-04T02:30:00.000Z',
  'createdAt': '2026-09-01T07:09:19.931Z',
  'updatedAt': '2026-09-01T07:09:19.931Z',
};

void main() {
  group('the task request', () {
    test('always asks for tasks of the selected department', () {
      final query = buildTaskListQuery(page: 1, limit: 25, departmentId: apacId);

      expect(query['type'], 'task');
      expect(query['departmentId'], apacId);
      expect(query['department_id'], apacId);
      expect(query['page'], 1);
      expect(query['limit'], 25);
      expect(query['sort'], 'createdAt');
      expect(query['order'], 'desc');
    });

    test('the other department is never in the request', () {
      final apac = buildTaskListQuery(page: 1, limit: 25, departmentId: apacId);
      final australia = buildTaskListQuery(page: 1, limit: 25, departmentId: australiaId);

      expect(apac.values.contains(australiaId), isFalse);
      expect(australia.values.contains(apacId), isFalse);
      expect(australia['departmentId'], australiaId);
    });

    test('an empty search or filter is left out, not sent blank', () {
      final query = buildTaskListQuery(
        page: 1,
        limit: 25,
        departmentId: apacId,
        search: '   ',
        status: null,
        ownerId: '',
      );

      expect(query.containsKey('search'), isFalse);
      expect(query.containsKey('status'), isFalse);
      expect(query.containsKey('ownerId'), isFalse);
    });

    test('the status tab is sent to the API rather than filtered locally', () {
      final query = buildTaskListQuery(
        page: 1,
        limit: 25,
        departmentId: australiaId,
        status: 'completed',
      );

      expect(query['status'], 'completed');
      expect(query['type'], 'task');
    });

    test('paging keeps the department and the type', () {
      final query = buildTaskListQuery(page: 3, limit: 25, departmentId: apacId);

      expect(query['page'], 3);
      expect(query['departmentId'], apacId);
      expect(query['type'], 'task');
    });
  });

  group('a response is only used while it still belongs to the screen', () {
    test('the newest response for the selected department is used', () {
      expect(
        shouldApplyTaskResponse(
          responseSeq: 4,
          latestSeq: 4,
          requestedDepartmentId: apacId,
          selectedDepartmentId: apacId,
        ),
        isTrue,
      );
    });

    test('a response for the department just left is dropped', () {
      // APAC's reply lands after the user switched to Australia.
      expect(
        shouldApplyTaskResponse(
          responseSeq: 5,
          latestSeq: 5,
          requestedDepartmentId: apacId,
          selectedDepartmentId: australiaId,
        ),
        isFalse,
        reason: 'APAC tasks must never appear while Australia is selected',
      );
    });

    test('a response superseded by a newer request is dropped', () {
      expect(
        shouldApplyTaskResponse(
          responseSeq: 2,
          latestSeq: 3,
          requestedDepartmentId: apacId,
          selectedDepartmentId: apacId,
        ),
        isFalse,
      );
    });

    test('switching away and back still accepts only the newest request', () {
      // APAC → Australia → APAC leaves request 3 in flight for APAC.
      expect(
        shouldApplyTaskResponse(
          responseSeq: 1,
          latestSeq: 3,
          requestedDepartmentId: apacId,
          selectedDepartmentId: apacId,
        ),
        isFalse,
        reason: 'the first APAC reply is stale even though APAC is selected again',
      );
      expect(
        shouldApplyTaskResponse(
          responseSeq: 3,
          latestSeq: 3,
          requestedDepartmentId: apacId,
          selectedDepartmentId: apacId,
        ),
        isTrue,
      );
    });
  });

  group('reading a task row', () {
    test('the scheduled date is shown, with nothing invented when absent', () {
      final row = Map<String, dynamic>.from(_apiRow);

      expect(activityDueLabel(row), isNotNull);
      expect(activityDueLabel(row), contains('/'));
      expect(activityDueLabel({'id': 'x'}), isNull,
          reason: 'a row with no date must not be given a made-up one');
    });

    test('assignees are read before the owner and the creator', () {
      expect(
        activityAssigneeLabel({
          'assignees': [
            {'firstName': 'Sam', 'lastName': 'Patel'}
          ],
          'ownerName': 'Someone Else',
        }),
        'Sam Patel',
      );
      expect(
        activityAssigneeLabel({
          'assignees': [
            {'name': 'Sam Patel'},
            {'name': 'Ana Diaz'},
          ]
        }),
        'Sam Patel +1',
      );
      expect(activityAssigneeLabel({'ownerName': 'Sam Patel'}), 'Sam Patel');
      expect(activityAssigneeLabel({'creatorName': 'Ana Diaz'}), 'Ana Diaz');
    });

    test('a row that names nobody says so instead of naming a person', () {
      expect(activityAssigneeLabel(Map<String, dynamic>.from(_apiRow)), isNull);
    });

    test('the linked contact, company or deal is read from the row', () {
      expect(activityRelatedRecordLabel({'contactName': 'Jo Blue'}), 'Jo Blue');
      expect(
        activityRelatedRecordLabel({
          'contact': {'firstName': 'Jo', 'lastName': 'Blue'}
        }),
        'Jo Blue',
      );
      expect(activityRelatedRecordLabel({'companyName': 'Acme'}), 'Acme');
      expect(
        activityRelatedRecordLabel({
          'deal': {'title': 'Renewal 2026'}
        }),
        'Renewal 2026',
      );
      expect(activityRelatedRecordLabel(Map<String, dynamic>.from(_apiRow)), isNull);
    });
  });
}
