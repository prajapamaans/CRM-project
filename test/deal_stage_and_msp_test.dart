import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/network/api_service.dart';
import 'package:crmproject/core/network/dio_client.dart';
import 'package:crmproject/core/utils/msp_field_utils.dart';
import 'package:crmproject/features/deals/data/datasource/remote/deal_remote_datasource.dart';

/// Records the verb and path of each request and replies with [body].
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);

  final String body;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('updating a deal', () {
    test('goes straight to PATCH instead of a failing PUT first', () async {
      final adapter = _RecordingAdapter(
        jsonEncode({'id': 'deal-1', 'title': 'Acme', 'stage': 'RFI'}),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api'))
        ..httpClientAdapter = adapter;
      final dataSource = DealRemoteDataSourceImpl(
        apiService: ApiService(dioClient: DioClient(dio: dio)),
      );

      final deal = await dataSource.updateDeal('deal-1', {'stage': 'RFI'});

      // One request, and it is the documented one.
      expect(adapter.calls, ['PATCH /deals/deal-1']);
      expect(deal.stage, 'RFI');
    });
  });

  group('MspFieldUtils.namesFrom', () {
    test('splits the comma-separated field a record stores', () {
      expect(MspFieldUtils.namesFrom('Magnit, Beeline'), ['Magnit', 'Beeline']);
      expect(MspFieldUtils.namesFrom('Magnit'), ['Magnit']);
      expect(MspFieldUtils.namesFrom('  Magnit ,  , Beeline '), ['Magnit', 'Beeline']);
    });

    test('treats no MSP as an empty list', () {
      expect(MspFieldUtils.namesFrom(null), isEmpty);
      expect(MspFieldUtils.namesFrom(''), isEmpty);
      expect(MspFieldUtils.namesFrom('   '), isEmpty);
    });
  });
}
