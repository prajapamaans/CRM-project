import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/models/master_dropdown_model.dart';
import 'package:crmproject/core/network/api_service.dart';
import 'package:crmproject/core/network/network_exception.dart';
import 'package:crmproject/core/utils/activity_delete.dart';
import 'package:crmproject/core/utils/task_status_filter.dart';

/// A task as the API returns it: an id and whatever status it carries.
class _Row {
  final String id;
  final String status;
  const _Row(this.id, this.status);
}

const _page = [
  _Row('a', 'pending'),
  _Row('b', 'completed'),
  _Row('c', 'pending'),
  _Row('d', 'completed'),
];

List<String> _idsUnder(TaskStatusTab tab,
        {List<_Row> rows = _page, List<MasterDropdownOptionModel> options = const []}) =>
    rows
        .where((r) => taskStatusMatchesTab(r.status, tab, statusOptions: options))
        .map((r) => r.id)
        .toList();

MasterDropdownOptionModel _option(String value, String label) =>
    MasterDropdownOptionModel(id: value, value: value, label: label);

/// Records the deletes instead of sending them.
class _RecordingApiService extends ApiService {
  final List<String> deleted = [];
  final Set<String> rejects;

  _RecordingApiService({this.rejects = const {}});

  @override
  Future<Response<T>> delete<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    deleted.add(path);
    if (rejects.any(path.endsWith)) {
      throw const NetworkException(message: 'Server error occurred.', statusCode: 500);
    }
    return Response<T>(requestOptions: RequestOptions(path: path), statusCode: 204);
  }
}

void main() {
  group('the status tabs split the page by the API status', () {
    test('All shows pending and completed alike', () {
      expect(_idsUnder(TaskStatusTab.all), ['a', 'b', 'c', 'd']);
    });

    test('Pending shows only pending tasks', () {
      expect(_idsUnder(TaskStatusTab.pending), ['a', 'c']);
    });

    test('Completed shows only completed tasks', () {
      expect(_idsUnder(TaskStatusTab.completed), ['b', 'd']);
    });

    test('a status the tabs do not cover stays under All', () {
      const rows = [
        _Row('a', 'pending'),
        _Row('b', 'cancelled'),
        _Row('c', 'reopened'),
        _Row('d', 'completed'),
      ];

      expect(_idsUnder(TaskStatusTab.all, rows: rows), ['a', 'b', 'c', 'd']);
      expect(_idsUnder(TaskStatusTab.pending, rows: rows), ['a']);
      expect(_idsUnder(TaskStatusTab.completed, rows: rows), ['d']);
    });

    test('how the backend cases or spaces a status does not matter', () {
      const rows = [_Row('a', 'Pending'), _Row('b', ' COMPLETED '), _Row('c', 'In Progress')];

      expect(_idsUnder(TaskStatusTab.pending, rows: rows), ['a']);
      expect(_idsUnder(TaskStatusTab.completed, rows: rows), ['b']);
      expect(_idsUnder(TaskStatusTab.all, rows: rows), ['a', 'b', 'c']);
    });

    test('a missing status never counts as pending or completed', () {
      const rows = [_Row('a', ''), _Row('b', 'completed')];

      expect(_idsUnder(TaskStatusTab.pending, rows: rows), isEmpty);
      expect(_idsUnder(TaskStatusTab.completed, rows: rows), ['b']);
      expect(_idsUnder(TaskStatusTab.all, rows: rows), ['a', 'b']);
    });
  });

  group('the value sent to the API comes from the backend', () {
    test('All filters nothing, so no status is sent', () {
      expect(taskStatusValueFor(TaskStatusTab.all), isNull);
    });

    test("the backend's own task_status value wins over the documented one", () {
      final options = [_option('TASK_PENDING', 'Pending'), _option('TASK_DONE', 'Completed')];

      expect(taskStatusValueFor(TaskStatusTab.pending, statusOptions: options), 'TASK_PENDING');
      expect(taskStatusValueFor(TaskStatusTab.completed, statusOptions: options), 'TASK_DONE');
    });

    test('tasks are matched against that same backend value', () {
      final options = [_option('TASK_PENDING', 'Pending'), _option('TASK_DONE', 'Completed')];
      const rows = [_Row('a', 'TASK_PENDING'), _Row('b', 'TASK_DONE')];

      expect(_idsUnder(TaskStatusTab.pending, rows: rows, options: options), ['a']);
      expect(_idsUnder(TaskStatusTab.completed, rows: rows, options: options), ['b']);
    });

    test('the documented status is used when the dropdown has not loaded', () {
      expect(taskStatusValueFor(TaskStatusTab.pending), 'pending');
      expect(taskStatusValueFor(TaskStatusTab.completed), 'completed');
    });

    test('an unrelated dropdown is ignored rather than guessed at', () {
      final options = [_option('low', 'Low'), _option('high', 'High')];

      expect(taskStatusValueFor(TaskStatusTab.completed, statusOptions: options), 'completed');
    });
  });

  group('deleting the selected tasks', () {
    test('each selected task is deleted through the documented endpoint', () async {
      final api = _RecordingApiService();

      final result = await deleteActivities(['a', 'c'], apiService: api);

      expect(api.deleted, ['/activities/a', '/activities/c']);
      expect(result.deleted, ['a', 'c']);
      expect(result.allSucceeded, isTrue);
    });

    test('only the selected tasks are touched', () async {
      final api = _RecordingApiService();

      // Page holds a, b, c, d — the user ticked two of them.
      await deleteActivities(['b', 'd'], apiService: api);

      expect(api.deleted, ['/activities/b', '/activities/d']);
      expect(api.deleted.any((p) => p.endsWith('/a') || p.endsWith('/c')), isFalse);
    });

    test('a task the backend refuses is reported, not counted as deleted', () async {
      final api = _RecordingApiService(rejects: {'/c'});

      final result = await deleteActivities(['a', 'c'], apiService: api);

      expect(result.deleted, ['a']);
      expect(result.failed, ['c']);
      expect(result.allSucceeded, isFalse);
    });

    test('one failure does not stop the rest of the batch', () async {
      final api = _RecordingApiService(rejects: {'/a'});

      final result = await deleteActivities(['a', 'b', 'c'], apiService: api);

      expect(api.deleted, hasLength(3));
      expect(result.deleted, ['b', 'c']);
      expect(result.failed, ['a']);
    });

    test('nothing selected sends nothing', () async {
      final api = _RecordingApiService();

      final result = await deleteActivities(const [], apiService: api);

      expect(api.deleted, isEmpty);
      expect(result.deleted, isEmpty);
      expect(result.failed, isEmpty);
    });
  });
}
