import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/datasources/master_data_remote_datasource.dart';
import 'package:crmproject/core/network/api_constants.dart';
import 'package:crmproject/core/network/api_service.dart';
import 'package:crmproject/core/network/network_exception.dart';

/// One HTTP call the datasource made.
class _Call {
  final String method;
  final String path;
  final dynamic data;
  const _Call(this.method, this.path, this.data);

  @override
  String toString() => '$method $path $data';
}

/// Records every request instead of sending it, and answers with whatever the
/// test set up for that method+path.
class _RecordingApiService extends ApiService {
  final List<_Call> calls = [];

  /// Keyed by 'METHOD /path'. A [NetworkException] value is thrown, anything
  /// else is returned as the response body.
  final Map<String, Object> handlers;

  _RecordingApiService({Map<String, Object>? handlers}) : handlers = handlers ?? {};

  Future<Response<T>> _record<T>(String method, String path, dynamic data) async {
    calls.add(_Call(method, path, data));
    final handler = handlers['$method $path'];
    if (handler is NetworkException) throw handler;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: handler as T?,
    );
  }

  @override
  Future<Response<T>> post<T>(String path,
          {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _record<T>('POST', path, data);

  @override
  Future<Response<T>> put<T>(String path,
          {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _record<T>('PUT', path, data);

  @override
  Future<Response<T>> patch<T>(String path,
          {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _record<T>('PATCH', path, data);

  @override
  Future<Response<T>> get<T>(String path,
          {Map<String, dynamic>? queryParameters, Options? options}) =>
      _record<T>('GET', path, null);

  @override
  Future<Response<T>> delete<T>(String path,
          {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) =>
      _record<T>('DELETE', path, data);

  /// Every request that would add a record rather than change one.
  Iterable<_Call> get creatingCalls => calls.where(
        (c) => c.method == 'POST' || (c.method == 'PUT' && c.path == ApiConstants.emailSignatures),
      );
}

const _existingId = 'c5e5f5f1-5b6c-4e1d-96a7-09adff32500a';
const _root = ApiConstants.emailSignatures;
const _itemPath = '$_root/$_existingId';

void main() {
  late _RecordingApiService api;

  MasterDataRemoteDataSourceImpl dataSource() =>
      MasterDataRemoteDataSourceImpl(apiService: api);

  group('creating a signature', () {
    setUp(() {
      api = _RecordingApiService(handlers: {
        'POST $_root': {'id': 'new-id', 'name': 'Sales', 'body': '<p>Hi</p>', 'isDefault': false},
      });
    });

    test('posts once to the collection endpoint', () async {
      final created = await dataSource().createEmailSignature({
        'name': 'Sales',
        'body': '<p>Hi</p>',
        'isDefault': false,
      });

      expect(api.calls, hasLength(1));
      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.path, _root);
      expect(created.id, 'new-id');
    });
  });

  group('editing an existing signature', () {
    setUp(() {
      api = _RecordingApiService(handlers: {
        'PUT $_itemPath': {
          'id': _existingId,
          'name': 'Renamed',
          'body': '<p>Changed</p>',
          'isDefault': true,
        },
      });
    });

    test('puts to the record endpoint and creates nothing', () async {
      final updated = await dataSource().updateEmailSignature(_existingId, {
        'name': 'Renamed',
        'body': '<p>Changed</p>',
        'isDefault': true,
      });

      expect(api.calls, hasLength(1));
      expect(api.calls.single.method, 'PUT');
      expect(api.calls.single.path, _itemPath);
      expect(api.creatingCalls, isEmpty, reason: 'editing must never add a second record');
      expect(updated.id, _existingId, reason: 'the edited record keeps its id');
    });

    test('the id travels in the path, not in the body', () async {
      await dataSource().updateEmailSignature(_existingId, {
        'id': _existingId,
        'name': 'Renamed',
        'body': '<p>Changed</p>',
        'isDefault': true,
      });

      final body = api.calls.single.data as Map<String, dynamic>;
      expect(body.containsKey('id'), isFalse);
      expect(body['name'], 'Renamed');
    });

    test('a payload that carries an id is updated, never created twice', () async {
      // The "make default" toggle used to reach the create method with an id.
      await dataSource().createEmailSignature({
        'id': _existingId,
        'name': 'Renamed',
        'body': '<p>Changed</p>',
        'isDefault': true,
      });

      expect(api.creatingCalls, isEmpty);
      expect(api.calls.single.method, 'PUT');
      expect(api.calls.single.path, _itemPath);
    });

    test('a bare acknowledgement still resolves to the same record', () async {
      api = _RecordingApiService(handlers: {'PUT $_itemPath': {'success': true}});

      final updated = await dataSource().updateEmailSignature(_existingId, {'name': 'Renamed'});

      expect(updated.id, _existingId);
    });
  });

  group('a failed update never falls through to a create', () {
    test('a rejected update is reported, not retried elsewhere', () async {
      api = _RecordingApiService(handlers: {
        'PUT $_itemPath': const NetworkException(message: 'Validation error.', statusCode: 422),
      });

      await expectLater(
        dataSource().updateEmailSignature(_existingId, {'name': 'Renamed'}),
        throwsA(isA<NetworkException>()),
      );

      expect(api.calls, hasLength(1));
      expect(api.creatingCalls, isEmpty,
          reason: 'the old fallback wrote to the collection endpoint, which duplicated the record');
    });

    test('an unsupported method retries PATCH on the same record', () async {
      api = _RecordingApiService(handlers: {
        'PUT $_itemPath': const NetworkException(message: 'Method not allowed.', statusCode: 405),
        'PATCH $_itemPath': {'id': _existingId, 'name': 'Renamed', 'body': '<p>x</p>'},
      });

      final updated = await dataSource().updateEmailSignature(_existingId, {'name': 'Renamed'});

      expect(api.calls.map((c) => '${c.method} ${c.path}'),
          ['PUT $_itemPath', 'PATCH $_itemPath']);
      expect(api.creatingCalls, isEmpty);
      expect(updated.id, _existingId);
    });

    test('an update with no id is refused before any request goes out', () async {
      api = _RecordingApiService();

      await expectLater(
        dataSource().updateEmailSignature('  ', {'name': 'Renamed'}),
        throwsA(isA<ArgumentError>()),
      );

      expect(api.calls, isEmpty);
    });
  });
}
