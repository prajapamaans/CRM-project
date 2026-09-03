import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/datasources/master_data_remote_datasource.dart';
import 'package:crmproject/core/network/api_service.dart';
import 'package:crmproject/core/network/network_exception.dart';

class _Write {
  final String method;
  final String path;
  final Map<String, dynamic> body;
  const _Write(this.method, this.path, this.body);

  @override
  String toString() => '$method $path $body';
}

/// Records writes and answers with whatever the test set up for that route.
class _RecordingApiService extends ApiService {
  final List<_Write> writes = [];

  /// Keyed by 'METHOD /path'. A [NetworkException] is thrown, anything else is
  /// returned as the response body.
  final Map<String, Object> handlers;

  _RecordingApiService({Map<String, Object>? handlers}) : handlers = handlers ?? {};

  Future<Response<T>> _record<T>(String method, String path, dynamic data) async {
    writes.add(_Write(method, path, Map<String, dynamic>.from(data as Map)));
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
}

const _root = '/email-templates';
const _list = '/email-templates/list';
const _templateId = '0f4d2f4f-58a6-4c4a-9d3a-8fd0f6a2a111';

/// What the form sends for a template created at the root level.
Map<String, dynamic> _rootTemplate() => {
      'name': 'gxhvu',
      'subject': 'Hello',
      'body': '<p>Hi</p>',
      'sharedSetting': 'private',
      'folderId': null,
    };

void main() {
  late _RecordingApiService api;

  MasterDataRemoteDataSourceImpl dataSource() =>
      MasterDataRemoteDataSourceImpl(apiService: api);

  group('saving a new template', () {
    test('a template at the root level is sent without a null folder', () async {
      api = _RecordingApiService(handlers: {'POST $_root': {'id': 'new', 'name': 'gxhvu'}});

      await dataSource().createEmailTemplate(_rootTemplate());

      final body = api.writes.single.body;
      expect(body.containsKey('folderId'), isFalse,
          reason: '"folderId": null is what a strict validator rejects');
      expect(body['name'], 'gxhvu');
      expect(body['subject'], 'Hello');
      expect(body['sharedSetting'], 'private');
    });

    test('a real folder is still sent', () async {
      api = _RecordingApiService(handlers: {'POST $_root': {'id': 'new'}});

      await dataSource().createEmailTemplate({..._rootTemplate(), 'folderId': 'f1'});

      expect(api.writes.single.body['folderId'], 'f1');
    });

    test('a blank id is dropped, but a blank subject is left alone', () async {
      api = _RecordingApiService(handlers: {'POST $_root': {'id': 'new'}});

      await dataSource().createEmailTemplate({
        'name': 'gxhvu',
        'subject': '',
        'body': '<p></p>',
        'folderId': '   ',
      });

      final body = api.writes.single.body;
      expect(body.containsKey('folderId'), isFalse);
      expect(body['subject'], '', reason: 'an empty subject is the user\'s choice, not a bad id');
    });
  });

  group('a rejected save is reported, not retried elsewhere', () {
    test('a validation error reaches the caller with the server message', () async {
      api = _RecordingApiService(handlers: {
        'POST $_root': const NetworkException(
          message: 'folderId must be a valid UUID',
          statusCode: 400,
        ),
      });

      await expectLater(
        dataSource().createEmailTemplate(_rootTemplate()),
        throwsA(isA<NetworkException>()
            .having((e) => e.message, 'message', 'folderId must be a valid UUID')
            .having((e) => e.statusCode, 'statusCode', 400)),
      );

      expect(api.writes, hasLength(1),
          reason: 'the rejected body used to be posted a second time to the listing path');
    });

    test('a missing route is retried on the listing path', () async {
      api = _RecordingApiService(handlers: {
        'POST $_root': const NetworkException(message: 'Resource not found.', statusCode: 404),
        'POST $_list': {'id': 'new', 'name': 'gxhvu'},
      });

      final created = await dataSource().createEmailTemplate(_rootTemplate());

      expect(api.writes.map((w) => '${w.method} ${w.path}'), ['POST $_root', 'POST $_list']);
      expect(created['id'], 'new');
    });
  });

  group('saving changes to an existing template', () {
    test('the id travels in the path and the null folder is dropped', () async {
      api = _RecordingApiService(handlers: {'PUT $_root/$_templateId': {'id': _templateId}});

      await dataSource().updateEmailTemplate(_templateId, {
        'id': _templateId,
        'name': 'gxhvu',
        'body': '<p>Hi</p>',
        'folderId': null,
      });

      expect(api.writes.single.path, '$_root/$_templateId');
      expect(api.writes.single.body.containsKey('id'), isFalse);
      expect(api.writes.single.body.containsKey('folderId'), isFalse);
    });

    test('a rejected update is not written a second time', () async {
      api = _RecordingApiService(handlers: {
        'PUT $_root/$_templateId': const NetworkException(message: 'Validation error.', statusCode: 422),
      });

      await expectLater(
        dataSource().updateEmailTemplate(_templateId, {'name': 'gxhvu'}),
        throwsA(isA<NetworkException>()),
      );

      expect(api.writes, hasLength(1));
    });
  });
}
