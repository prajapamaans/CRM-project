import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/datasources/master_data_remote_datasource.dart';
import 'package:crmproject/core/network/api_service.dart';
import 'package:crmproject/core/network/dio_client.dart';

/// Serves a canned body for every request, standing in for the backend.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, {this.contentType = 'application/json'});

  final String body;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

MasterDataRemoteDataSourceImpl _dataSourceServing(
  String body, {
  String contentType = 'application/json',
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api'))
    ..httpClientAdapter = _StubAdapter(body, contentType: contentType);
  return MasterDataRemoteDataSourceImpl(
    apiService: ApiService(dioClient: DioClient(dio: dio)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The auth interceptor reads the stored token before every request.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GET /api/msp-options', () {
    test('parses the direct array of names the API returns', () async {
      final dataSource = _dataSourceServing(
        jsonEncode(['Magnit', 'Beeline', 'agileOne']),
      );

      final options = await dataSource.getMspOptions();

      expect(options.map((e) => e.name).toList(), ['Magnit', 'Beeline', 'agileOne']);
      expect(options.map((e) => e.position).toList(), [0, 1, 2]);
    });

    test('keeps working when the body is not typed as JSON', () async {
      final dataSource = _dataSourceServing(
        jsonEncode(['Magnit', 'Beeline']),
        contentType: 'text/plain',
      );

      final options = await dataSource.getMspOptions();

      expect(options.map((e) => e.name).toList(), ['Magnit', 'Beeline']);
    });

    test('drops blank entries and duplicates', () async {
      final dataSource = _dataSourceServing(
        jsonEncode(['Magnit', '  ', 'magnit', 'Beeline']),
      );

      final options = await dataSource.getMspOptions();

      expect(options.map((e) => e.name).toList(), ['Magnit', 'Beeline']);
    });

    test('returns an empty list for an empty response', () async {
      final dataSource = _dataSourceServing(jsonEncode(<String>[]));

      expect(await dataSource.getMspOptions(), isEmpty);
    });

    test('still reads object entries', () async {
      final dataSource = _dataSourceServing(
        jsonEncode([
          {'id': 'msp-1', 'name': 'Magnit'},
        ]),
      );

      final options = await dataSource.getMspOptions();

      expect(options.single.id, 'msp-1');
      expect(options.single.name, 'Magnit');
    });
  });
}
