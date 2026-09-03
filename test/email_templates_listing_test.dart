import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/datasources/master_data_remote_datasource.dart';
import 'package:crmproject/core/models/email_template_models.dart';
import 'package:crmproject/core/network/api_service.dart';

/// Answers each GET with whatever the test set up for that path.
class _RecordingApiService extends ApiService {
  final List<String> requested = [];
  final Map<String, Object?> responses;

  _RecordingApiService(this.responses);

  @override
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters, Options? options}) async {
    final query = (queryParameters ?? const {})
        .entries
        // Both spellings of the department carry the same value; one is enough
        // to key the response on.
        .where((e) => e.key != 'department_id')
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    final key = query.isEmpty ? path : '$path?$query';
    requested.add(key);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: responses[key] as T?,
    );
  }
}

const _templateRow = {
  'id': 't1',
  'name': 'Intro email',
  'subject': 'Hello',
  'body': '<p>Hi</p>',
  'folderId': null,
};

void main() {
  group('reading the template listing', () {
    test('templates and folders at the top level are read', () {
      final parsed = EmailTemplatesResponse.fromJson({
        'success': true,
        'folders': [
          {'id': 'f1', 'name': 'Sales'}
        ],
        'templates': [_templateRow],
      });

      expect(parsed.templates.single.name, 'Intro email');
      expect(parsed.folders.single.name, 'Sales');
      expect(parsed.success, isTrue);
    });

    test('a wrapped response is unwrapped instead of read as empty', () {
      // This shape used to parse as zero templates, which is what showed a
      // saved template as an empty screen after a reload.
      final parsed = EmailTemplatesResponse.fromJson({
        'success': true,
        'data': {
          'folders': [
            {'id': 'f1', 'name': 'Sales'}
          ],
          'templates': [_templateRow],
        },
      });

      expect(parsed.templates.single.id, 't1');
      expect(parsed.folders.single.id, 'f1');
    });

    test('a response whose data is the template list itself is read', () {
      final parsed = EmailTemplatesResponse.fromJson({
        'success': true,
        'data': [_templateRow],
      });

      expect(parsed.templates.single.id, 't1');
      expect(parsed.folders, isEmpty);
    });

    test('the other names the listing uses for its lists are accepted', () {
      final parsed = EmailTemplatesResponse.fromJson({
        'items': [_templateRow],
        'emailTemplateFolders': [
          {'id': 'f2', 'name': 'Marketing'}
        ],
      });

      expect(parsed.templates.single.id, 't1');
      expect(parsed.folders.single.id, 'f2');
    });

    test('a response with nothing recognisable parses to empty, not an error', () {
      final parsed = EmailTemplatesResponse.fromJson({'message': 'no templates'});

      expect(parsed.templates, isEmpty);
      expect(parsed.folders, isEmpty);
    });
  });

  group('the templates screen request', () {
    test('a wrapped listing is read rather than shown as an empty folder', () async {
      final api = _RecordingApiService({
        '/email-templates/list?flat=true': {
          'success': true,
          'data': {
            'templates': [_templateRow],
          },
        },
      });

      final result = await MasterDataRemoteDataSourceImpl(apiService: api).getEmailTemplatesFull();

      expect(api.requested, ['/email-templates/list?flat=true']);
      expect(result.templates.single.id, 't1',
          reason: 'a saved template must not be reported as an empty folder');
    });

    test('the listing is asked for once', () async {
      final api = _RecordingApiService({
        '/email-templates/list?flat=true': {
          'success': true,
          'templates': [_templateRow],
        },
      });

      final result = await MasterDataRemoteDataSourceImpl(apiService: api).getEmailTemplatesFull();

      expect(api.requested, ['/email-templates/list?flat=true']);
      expect(result.templates, hasLength(1));
    });

    test('a listing answering with a bare array is read as templates', () async {
      final api = _RecordingApiService({
        '/email-templates/list?flat=true': [_templateRow],
      });

      final result = await MasterDataRemoteDataSourceImpl(apiService: api).getEmailTemplatesFull();

      expect(result.templates.single.name, 'Intro email');
    });

    test('genuinely empty stays empty, and is not asked for again', () async {
      final api = _RecordingApiService({
        '/email-templates/list?flat=true': {'success': true, 'folders': [], 'templates': []},
      });

      final result = await MasterDataRemoteDataSourceImpl(apiService: api).getEmailTemplatesFull();

      expect(result.templates, isEmpty);
      expect(result.folders, isEmpty);
      expect(api.requested, hasLength(1));
    });

    test('the selected department is part of the listing request', () async {
      final api = _RecordingApiService({
        '/email-templates/list?flat=true&departmentId=dept-1': {
          'templates': [_templateRow],
        },
      });

      await MasterDataRemoteDataSourceImpl(apiService: api)
          .getEmailTemplatesFull(departmentId: 'dept-1');

      expect(api.requested.single, contains('departmentId=dept-1'));
    });
  });
}
