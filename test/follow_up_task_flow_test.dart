import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/network/api_service.dart';
import 'package:crmproject/core/network/network_exception.dart';
import 'package:crmproject/core/storage/follow_up_link_storage.dart';
import 'package:crmproject/core/utils/department_scope.dart';
import 'package:crmproject/core/utils/follow_up_schedule.dart';
import 'package:crmproject/core/utils/follow_up_task_request.dart';
import 'package:crmproject/core/utils/task_activity_history.dart';
import 'package:crmproject/features/dashboard/data/models/activity_stats_model.dart';
import 'package:crmproject/features/dashboard/data/models/dashboard_unified_model.dart';
import 'package:crmproject/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:crmproject/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:crmproject/features/departments/presentation/providers/department_provider.dart';

final apacId = DepartmentConstants.apacId;
final australiaId = DepartmentConstants.australiaId;

/// A task exactly as `GET /api/activities?type=task` returns one, linked to a
/// contact and a company and owned by somebody.
Map<String, dynamic> pendingTask() => {
      'id': 'task-1',
      'organizationId': '2570be88-821b-43af-92a9-3aced45f8fcd',
      'ownerId': 'owner-9',
      'type': 'task',
      'title': 'Call Mastercard',
      'description': 'Ask about the renewal',
      'status': 'pending',
      'priority': 'high',
      'queue': 'follow-up 1',
      'reminderType': '1 hour before',
      'contactId': 'contact-4',
      'companyId': 'company-7',
      'scheduledAt': '2026-09-01T02:30:00.000Z',
      'createdAt': '2026-08-28T07:09:19.931Z',
      'updatedAt': '2026-08-28T07:09:19.931Z',
    };

/// Records every call and answers with whatever the test lined up.
class _FakeApiService extends ApiService {
  final List<({String method, String path, dynamic data, Map<String, dynamic>? query})>
      calls = [];

  /// path -> the answer, or a thrown error.
  final Map<String, dynamic Function()> responses = {};

  Response<T> _answer<T>(
    String method,
    String path,
    dynamic data,
    Map<String, dynamic>? query,
  ) {
    calls.add((method: method, path: path, data: data, query: query));
    final build = responses[path];
    if (build == null) {
      throw NetworkException(message: 'no route $path', statusCode: 404);
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: build() as T?,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> patch<T>(String path,
          {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async =>
      _answer<T>('PATCH', path, data, queryParameters);

  @override
  Future<Response<T>> post<T>(String path,
          {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async =>
      _answer<T>('POST', path, data, queryParameters);
}

class _StubDashboardRepository implements DashboardRepository {
  @override
  Future<ActivityStatsModel> getActivityStats({
    String? ownerId,
    String? departmentId,
    String? startDate,
    String? endDate,
  }) async =>
      throw UnimplementedError();

  @override
  Future<DashboardUnifiedResponseModel> getDashboardUnified({
    String? ownerId,
    String? departmentId,
    String? startDate,
    String? endDate,
    int? page,
    int? limit,
  }) async =>
      throw UnimplementedError();
}

DashboardProvider _providerWith(_FakeApiService api, List<Map<String, dynamic>> tasks) {
  final provider = DashboardProvider(
    repository: _StubDashboardRepository(),
    apiService: api,
  );
  provider.dashboardTasks.addAll(tasks);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FollowUpLinkStorage.clearCache();
  });

  group('the follow-up date', () {
    test('skips the weekend when counting business days', () {
      // A Wednesday. Three business days later is the Monday, not the Saturday.
      final wednesday = DateTime(2026, 9, 2);
      expect(wednesday.weekday, DateTime.wednesday);

      final due = addBusinessDays(wednesday, 3);
      expect(due, DateTime(2026, 9, 7));
      expect(due.weekday, DateTime.monday);
    });

    test('opens three business days after the task was finished', () {
      final completedOn = DateTime(2026, 9, 1, 16, 20);
      expect(defaultFollowUpDate(from: completedOn), DateTime(2026, 9, 4));
    });

    test('names the weekday the chosen date genuinely falls on', () {
      final basis = DateTime(2026, 9, 1);

      expect(
        followUpDateLabel(DateTime(2026, 9, 4), from: basis),
        'In 3 business days (Friday)',
      );
      // A different completion day moves both the date and the day named:
      // Thursday plus three business days lands on the Tuesday.
      final laterBasis = DateTime(2026, 9, 3);
      expect(laterBasis.weekday, DateTime.thursday);
      expect(defaultFollowUpDate(from: laterBasis), DateTime(2026, 9, 8));
      expect(
        followUpDateLabel(defaultFollowUpDate(from: laterBasis), from: laterBasis),
        'In 3 business days (Tuesday)',
      );
    });

    test('spells out a hand-picked date with its own weekday', () {
      expect(
        followUpDateLabel(DateTime(2026, 12, 25), from: DateTime(2026, 9, 1)),
        'Dec 25, 2026 (Friday)',
      );
    });

    test('reads a time back and joins it to the chosen day', () {
      final due = combineDateAndTime(DateTime(2026, 9, 4), '08:00 AM');
      expect(due, DateTime(2026, 9, 4, 8, 0));

      expect(combineDateAndTime(DateTime(2026, 9, 4), '4:45 PM'),
          DateTime(2026, 9, 4, 16, 45));
      // Nonsense leaves the day alone rather than silently becoming 8am.
      expect(combineDateAndTime(DateTime(2026, 9, 4, 11), 'whenever'),
          DateTime(2026, 9, 4, 11));
    });

    test('offers the quarter hours, written as the popup writes them', () {
      final options = followUpTimeOptions(padHour: true);
      expect(options.length, 96);
      expect(options.first, '12:00 AM');
      expect(options.contains('08:00 AM'), isTrue);
      expect(options.contains('04:45 PM'), isTrue);
    });
  });

  group('the follow-up task body', () {
    test('keeps the original task\'s name, owner and every linked record', () {
      final payload = buildFollowUpTaskPayload(
        original: pendingTask(),
        scheduledAt: DateTime(2026, 9, 4, 8),
      );

      expect(payload['type'], 'task');
      expect(payload['title'], 'Call Mastercard');
      expect(payload['description'], 'Ask about the renewal');
      expect(payload['ownerId'], 'owner-9');
      expect(payload['priority'], 'high');
      expect(payload['queue'], 'follow-up 1');
      expect(payload['reminderType'], '1 hour before');
      expect(payload['contactId'], 'contact-4');
      expect(payload['companyId'], 'company-7');
      expect(payload['associations'], [
        {'objectId': 'contact-4', 'objectType': 'contact'},
        {'objectId': 'company-7', 'objectType': 'company'},
      ]);
    });

    test('is due at the date and time that were picked', () {
      final payload = buildFollowUpTaskPayload(
        original: pendingTask(),
        scheduledAt: combineDateAndTime(DateTime(2026, 9, 4), '08:00 AM'),
      );

      expect(
        payload['scheduledAt'],
        DateTime(2026, 9, 4, 8).toUtc().toIso8601String(),
      );
    });

    test('starts pending — status is never sent on a create', () {
      final payload = buildFollowUpTaskPayload(
        original: {...pendingTask(), 'status': 'completed'},
        scheduledAt: DateTime(2026, 9, 4, 8),
      );

      expect(payload.containsKey('status'), isFalse);
      expect(payload.containsKey('completedAt'), isFalse);
    });

    test('leaves out what the original does not carry', () {
      final payload = buildFollowUpTaskPayload(
        original: {'id': 'task-2', 'type': 'task', 'title': 'Bare task'},
        scheduledAt: DateTime(2026, 9, 4, 8),
      );

      expect(payload.keys, containsAll(['type', 'title', 'scheduledAt']));
      expect(payload.containsKey('ownerId'), isFalse);
      expect(payload.containsKey('priority'), isFalse);
      expect(payload.containsKey('queue'), isFalse);
      expect(payload.containsKey('associations'), isFalse);
    });

    test('carries no department — the API takes that from the token', () {
      final payload = buildFollowUpTaskPayload(
        original: pendingTask(),
        scheduledAt: DateTime(2026, 9, 4, 8),
      );

      expect(payload.containsKey('departmentId'), isFalse);
      expect(payload.containsKey('department_id'), isFalse);
      expect(payload.values.contains(apacId), isFalse);
      expect(payload.values.contains(australiaId), isFalse);
    });
  });

  group('completing a task', () {
    test('goes through the endpoint built for it and keeps the server row', () async {
      final api = _FakeApiService();
      api.responses['/activities/task-1/complete'] = () => {
            ...pendingTask(),
            'status': 'completed',
            'completedAt': '2026-09-01T10:50:00.000Z',
          };

      final provider = _providerWith(api, [pendingTask()]);
      final result = await provider.setTaskStatus('task-1', 'completed');

      expect(api.calls.single.method, 'PATCH');
      expect(api.calls.single.path, '/activities/task-1/complete');
      expect(result['status'], 'completed');
      expect(result['completedAt'], '2026-09-01T10:50:00.000Z');
      expect(provider.dashboardTasks.single['status'], 'completed');
    });

    test('falls back to the plain update where that route is not deployed', () async {
      final api = _FakeApiService();
      // No /complete route registered, so the fake answers 404.
      api.responses['/activities/task-1'] =
          () => {...pendingTask(), 'status': 'completed'};

      final provider = _providerWith(api, [pendingTask()]);
      await provider.setTaskStatus('task-1', 'completed');

      expect(api.calls.map((c) => c.path).toList(),
          ['/activities/task-1/complete', '/activities/task-1']);
      expect(api.calls.last.data['status'], 'completed');
      expect(api.calls.last.data['completedAt'], isNotNull);
    });

    test('a refused completion throws and leaves the task pending', () async {
      final api = _FakeApiService();
      api.responses['/activities/task-1/complete'] =
          () => throw const NetworkException(message: 'Server error', statusCode: 500);

      final provider = _providerWith(api, [pendingTask()]);

      await expectLater(
        provider.setTaskStatus('task-1', 'completed'),
        throwsA(isA<NetworkException>()),
      );
      // Nothing on screen may claim it was completed.
      expect(provider.dashboardTasks.single['status'], 'pending');
    });

    test('unticking a completed task is a plain status update', () async {
      final api = _FakeApiService();
      api.responses['/activities/task-1'] =
          () => {...pendingTask(), 'status': 'pending'};

      final provider = _providerWith(api, [
        {...pendingTask(), 'status': 'completed'}
      ]);
      await provider.setTaskStatus('task-1', 'pending');

      expect(api.calls.single.path, '/activities/task-1');
      expect(api.calls.single.data, {'status': 'pending'});
    });
  });

  group('creating the follow-up', () {
    _FakeApiService apiThatCreates() {
      final api = _FakeApiService();
      api.responses['/activities'] = () => {
            'id': 'task-2',
            'type': 'task',
            'title': 'Call Mastercard',
            'status': 'pending',
            'scheduledAt': '2026-09-04T02:30:00.000Z',
            'createdAt': '2026-09-01T10:50:00.000Z',
            'updatedAt': '2026-09-01T10:50:00.000Z',
          };
      api.responses['/activities/task-2/tags'] = () => {'success': true};
      return api;
    }

    test('posts a real task and shows it on the dashboard', () async {
      final api = apiThatCreates();
      final provider = _providerWith(api, [pendingTask()]);

      final created = await provider.createFollowUpTask(
        original: {...pendingTask(), 'status': 'completed'},
        scheduledAt: DateTime(2026, 9, 4, 8),
        departmentId: apacId,
        selectedDepartmentId: apacId,
      );

      final post = api.calls.firstWhere((c) => c.path == '/activities');
      expect(post.method, 'POST');
      expect(post.data['title'], 'Call Mastercard');
      expect(created['id'], 'task-2');
      expect(provider.dashboardTasks.map((t) => t['id']), ['task-1', 'task-2']);
    });

    test('ties the new task back to the one it follows up on', () async {
      final api = apiThatCreates();
      final provider = _providerWith(api, [pendingTask()]);

      await provider.createFollowUpTask(
        original: {...pendingTask(), 'status': 'completed'},
        scheduledAt: DateTime(2026, 9, 4, 8),
        departmentId: apacId,
        selectedDepartmentId: apacId,
      );

      final tagCall = api.calls.firstWhere((c) => c.path.endsWith('/tags'));
      expect(tagCall.data, {'tag': 'follow-up-of:task-1'});
      expect(await FollowUpLinkStorage.followUpIdsFor('task-1'), ['task-2']);
      expect(await FollowUpLinkStorage.originalIdFor('task-2'), 'task-1');
    });

    test('a second Create task does not file a second follow-up', () async {
      final api = apiThatCreates();
      final provider = _providerWith(api, [pendingTask()]);
      final original = {...pendingTask(), 'status': 'completed'};

      final first = await provider.createFollowUpTask(
        original: original,
        scheduledAt: DateTime(2026, 9, 4, 8),
        departmentId: apacId,
        selectedDepartmentId: apacId,
      );
      final second = await provider.createFollowUpTask(
        original: original,
        scheduledAt: DateTime(2026, 9, 4, 8),
        departmentId: apacId,
        selectedDepartmentId: apacId,
      );

      expect(second['id'], first['id']);
      expect(api.calls.where((c) => c.path == '/activities').length, 1);
    });

    test('is abandoned when the department changed while the popup was open',
        () async {
      final api = apiThatCreates();
      final provider = _providerWith(api, [pendingTask()]);

      await expectLater(
        provider.createFollowUpTask(
          original: {...pendingTask(), 'status': 'completed'},
          scheduledAt: DateTime(2026, 9, 4, 8),
          departmentId: apacId,
          selectedDepartmentId: australiaId,
        ),
        throwsA(isA<StateError>()),
      );

      expect(api.calls, isEmpty);
      expect(provider.dashboardTasks.length, 1);
    });

    test('a create that fails leaves nothing behind on the dashboard', () async {
      final api = _FakeApiService();
      api.responses['/activities'] =
          () => throw const NetworkException(message: 'Validation failed', statusCode: 400);

      final provider = _providerWith(api, [pendingTask()]);

      await expectLater(
        provider.createFollowUpTask(
          original: {...pendingTask(), 'status': 'completed'},
          scheduledAt: DateTime(2026, 9, 4, 8),
          departmentId: apacId,
          selectedDepartmentId: apacId,
        ),
        throwsA(isA<NetworkException>()),
      );

      expect(provider.dashboardTasks.length, 1);
      expect(await FollowUpLinkStorage.followUpIdsFor('task-1'), isEmpty);
    });

    test('a tag the server will not take does not undo the created task', () async {
      final api = _FakeApiService();
      api.responses['/activities'] = () => {
            'id': 'task-2',
            'title': 'Call Mastercard',
            'status': 'pending',
            'createdAt': '2026-09-01T10:50:00.000Z',
          };
      // No /tags route: the fake answers 404.

      final provider = _providerWith(api, [pendingTask()]);
      final created = await provider.createFollowUpTask(
        original: {...pendingTask(), 'status': 'completed'},
        scheduledAt: DateTime(2026, 9, 4, 8),
        departmentId: apacId,
        selectedDepartmentId: apacId,
      );

      expect(created['id'], 'task-2');
      expect(provider.dashboardTasks.length, 2);
    });
  });

  group('the department', () {
    test('is resolved from the picker, then the account, never a constant', () {
      // Whatever the user picked wins.
      expect(
        resolveActiveDepartmentId(
          selected: australiaId,
          userDepartmentId: apacId,
          assignedDepartmentId: apacId,
        ),
        australiaId,
      );

      // Nothing picked yet: their own department, not a default.
      expect(
        resolveActiveDepartmentId(selected: null, userDepartmentId: australiaId),
        australiaId,
      );
      expect(
        resolveActiveDepartmentId(selected: '  ', assignedDepartmentId: australiaId),
        australiaId,
      );

      // Nothing known at all: say so, rather than claiming a department. The
      // request then names none and the API uses the token's own.
      expect(resolveActiveDepartmentId(), '');
      expect(departmentQuery(''), isEmpty);
      expect(resolveActiveDepartmentId() == apacId, isFalse);
    });

    test('is named both ways, as every other scoped call names it', () {
      expect(departmentQuery(australiaId), {
        'departmentId': australiaId,
        'department_id': australiaId,
      });
      expect(departmentQuery(null), isEmpty);
    });

    test('scopes completing a task to the department it was completed in',
        () async {
      final api = _FakeApiService();
      api.responses['/activities/task-1/complete'] =
          () => {...pendingTask(), 'status': 'completed'};

      final provider = _providerWith(api, [pendingTask()]);
      await provider.setTaskStatus('task-1', 'completed',
          departmentId: australiaId);

      expect(api.calls.single.query, {
        'departmentId': australiaId,
        'department_id': australiaId,
      });
    });

    test('files the follow-up in whichever department is active', () async {
      for (final departmentId in [apacId, australiaId]) {
        FollowUpLinkStorage.clearCache();
        SharedPreferences.setMockInitialValues({});

        final api = _FakeApiService();
        api.responses['/activities'] =
            () => {'id': 'task-2', 'title': 'Call Mastercard', 'status': 'pending'};
        api.responses['/activities/task-2/tags'] = () => {'success': true};

        final provider = _providerWith(api, [pendingTask()]);
        await provider.createFollowUpTask(
          original: {...pendingTask(), 'status': 'completed'},
          scheduledAt: DateTime(2026, 9, 4, 8),
          departmentId: departmentId,
          selectedDepartmentId: departmentId,
        );

        final other = departmentId == apacId ? australiaId : apacId;
        for (final call in api.calls) {
          expect(call.query, {
            'departmentId': departmentId,
            'department_id': departmentId,
          });
          // The department not in use never reaches the wire.
          expect(call.query!.values.contains(other), isFalse);
          expect(call.data.toString().contains(other), isFalse);
        }
      }
    });

    test('names no department when none is known, rather than guessing one',
        () async {
      final api = _FakeApiService();
      api.responses['/activities'] =
          () => {'id': 'task-2', 'title': 'Call Mastercard', 'status': 'pending'};
      api.responses['/activities/task-2/tags'] = () => {'success': true};

      final provider = _providerWith(api, [pendingTask()]);
      await provider.createFollowUpTask(
        original: {...pendingTask(), 'status': 'completed'},
        scheduledAt: DateTime(2026, 9, 4, 8),
        departmentId: '',
        selectedDepartmentId: '',
      );

      final post = api.calls.firstWhere((c) => c.path == '/activities');
      expect(post.query, isEmpty);
      expect(post.data.containsKey('departmentId'), isFalse);
    });
  });

  group('the task history', () {
    test('is built from the timestamps the task carries', () {
      final history = buildTaskActivityHistory({
        ...pendingTask(),
        'status': 'completed',
        'completedAt': '2026-09-01T10:50:00.000Z',
        'updatedAt': '2026-09-01T10:50:00.000Z',
        'owner': {'firstName': 'Priya', 'lastName': 'Sharma'},
      });

      expect(history.map((e) => e.kind).toList(),
          [TaskHistoryKind.created, TaskHistoryKind.completed]);
      expect(history.first.detail, 'Assigned to Priya Sharma');
      expect(history.last.at,
          DateTime.parse('2026-09-01T10:50:00.000Z').toLocal());
    });

    test('lists no completion for a task that was never completed', () {
      final history = buildTaskActivityHistory(pendingTask());

      expect(history.single.kind, TaskHistoryKind.created);
      expect(
        history.any((e) => e.kind == TaskHistoryKind.completed),
        isFalse,
      );
    });

    test('lists an edit only when the task was written again after creating', () {
      final untouched = buildTaskActivityHistory(pendingTask());
      expect(untouched.any((e) => e.kind == TaskHistoryKind.updated), isFalse);

      final edited = buildTaskActivityHistory({
        ...pendingTask(),
        'updatedAt': '2026-08-30T09:00:00.000Z',
      });
      expect(edited.map((e) => e.kind).toList(),
          [TaskHistoryKind.created, TaskHistoryKind.updated]);
    });

    test('runs on through the follow-ups, oldest first', () {
      final history = buildTaskActivityHistory(
        {
          ...pendingTask(),
          'status': 'completed',
          'completedAt': '2026-09-01T10:50:00.000Z',
          'updatedAt': '2026-09-01T10:50:00.000Z',
        },
        followUps: [
          {
            'id': 'task-2',
            'title': 'Call Mastercard',
            'status': 'completed',
            'scheduledAt': '2026-09-04T02:30:00.000Z',
            'createdAt': '2026-09-01T10:51:00.000Z',
            'completedAt': '2026-09-04T05:00:00.000Z',
          },
          {
            'id': 'task-3',
            'title': 'Call Mastercard',
            'status': 'pending',
            'scheduledAt': '2026-09-09T02:30:00.000Z',
            'createdAt': '2026-09-04T05:01:00.000Z',
          },
        ],
      );

      expect(history.map((e) => e.kind).toList(), [
        TaskHistoryKind.created,
        TaskHistoryKind.completed,
        TaskHistoryKind.followUpCreated,
        TaskHistoryKind.followUpCompleted,
        TaskHistoryKind.followUpCreated,
      ]);
      // The still-pending follow-up contributes no completion.
      expect(
        history.where((e) => e.kind == TaskHistoryKind.followUpCompleted).length,
        1,
      );
    });

    test('reads the link back out of the tag the API returned', () {
      expect(
        followUpParentIdFromTags({
          'id': 'task-2',
          'tags': ['urgent', 'follow-up-of:task-1'],
        }),
        'task-1',
      );
      expect(followUpParentIdFromTags({'id': 'task-1', 'tags': []}), isNull);
      expect(followUpParentIdFromTags({'id': 'task-1'}), isNull);
    });
  });
}
