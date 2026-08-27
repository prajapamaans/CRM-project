import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crmproject/core/network/api_service.dart';
import 'package:crmproject/core/network/dio_client.dart';
import 'package:crmproject/core/providers/master_data_provider.dart';
import 'package:crmproject/features/activities/data/models/meeting_scheduler_model.dart';
import 'package:crmproject/features/activities/presentation/providers/meeting_scheduler_provider.dart';
import 'package:crmproject/features/activities/presentation/screens/meeting_scheduler_screen.dart';
import 'package:crmproject/features/authentication/presentation/providers/auth_provider.dart';
import 'package:crmproject/features/companies/presentation/providers/company_provider.dart';
import 'package:crmproject/features/contacts/presentation/providers/contact_provider.dart';
import 'package:crmproject/features/deals/presentation/providers/deal_provider.dart';
import 'package:crmproject/features/departments/presentation/providers/department_provider.dart';

/// Serves canned replies for the save call and records every request.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.savedBody, this.saveStatus = 200, this.saveDelay});

  final String savedBody;
  final int saveStatus;
  final Duration? saveDelay;
  final List<String> calls = [];
  final List<String> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    final isSave = options.method == 'POST' || options.method == 'PATCH';
    if (isSave && options.data != null) bodies.add(jsonEncode(options.data));
    if (isSave && saveDelay != null) await Future<void>.delayed(saveDelay!);

    return ResponseBody.fromString(
      isSave ? savedBody : '[]',
      isSave ? saveStatus : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiService _apiWith(_StubAdapter adapter) => ApiService(
      dioClient: DioClient(
        dio: Dio(BaseOptions(baseUrl: 'http://localhost/api'))
          ..httpClientAdapter = adapter,
      ),
    );

MeetingScheduler _existing(String id) => MeetingScheduler(
      id: id,
      name: 'Intro call',
      slug: '/intro-call',
      durationOptions: const [30],
      availabilityWindow: const [],
      formFields: const [],
      reminderEmails: const [],
    );

/// Holds what the wizard returned once it closes — the list screen uses this
/// value to add the saved page, so it is the contract worth asserting on.
class _WizardResult {
  bool closed = false;
  MeetingScheduler? value;
}

Future<_WizardResult> _pumpWizard(
  WidgetTester tester, {
  required ApiService api,
  bool isEditMode = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);

  final result = _WizardResult();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MeetingSchedulerProvider(apiService: api)),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => DealProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MasterDataProvider()),
        ChangeNotifierProvider(create: (_) => DepartmentProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                // Pushed as a route, the way the list screen opens it.
                result.value = await Navigator.of(context).push<MeetingScheduler>(
                  MaterialPageRoute(
                    builder: (_) => CreateSchedulingPageWizardModal(
                      initialStep: 3,
                      isEditMode: isEditMode,
                      existingItem: _existing('s-1'),
                      apiService: api,
                    ),
                  ),
                );
                result.closed = true;
              },
              child: const Text('open wizard'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open wizard'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('creating a scheduling page', () {
    testWidgets('a failed save keeps the wizard open and reports the error',
        (tester) async {
      final adapter = _StubAdapter(
        savedBody: jsonEncode({'message': 'Internal name already in use'}),
        saveStatus: 400,
      );

      final wizard = await _pumpWizard(tester, api: _apiWith(adapter));
      await tester.tap(find.text('Create scheduling page'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // The old build popped with a locally built page and claimed success,
      // which is why the page vanished on the next refresh.
      expect(find.byType(CreateSchedulingPageWizardModal), findsOneWidget);
      expect(find.textContaining('Could not create the scheduling page'), findsWidgets);
      expect(find.textContaining('Internal name already in use'), findsWidgets);
      expect(wizard.closed, isFalse);
    });

    testWidgets('a successful save posts the fields the API reads back',
        (tester) async {
      final adapter = _StubAdapter(
        savedBody: jsonEncode({
          'id': 'srv-1',
          'name': 'Intro call',
          'slug': '/intro-call',
          'durationOptions': [15, 30],
        }),
      );

      final wizard = await _pumpWizard(tester, api: _apiWith(adapter));
      await tester.tap(find.text('Create scheduling page'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(adapter.calls, contains('POST /meeting-schedulers'));
      final body = jsonDecode(adapter.bodies.single) as Map<String, dynamic>;

      // Names that MeetingScheduler.fromJson understands, so the saved page
      // reads back with its real settings.
      expect(body['name'], 'Intro call');
      expect(body['durationOptions'], [30]);
      expect(body['timeZone'], 'UTC');
      expect(body['sendConfirmationEmail'], isTrue);
      expect(body['reminderEmails'], [
        {'value': 1, 'unit': 'day'},
      ]);
      expect((body['availabilityWindow'] as List).first, {
        'day': 'monday',
        'slots': [
          {'start': '09:00', 'end': '17:00'},
        ],
      });

      expect(wizard.closed, isTrue);
      expect(wizard.value, isNotNull);
    });

    testWidgets('sends the reminder count that was typed in', (tester) async {
      final adapter = _StubAdapter(
        savedBody: jsonEncode({'id': 'srv-3', 'name': 'Intro call', 'slug': '/intro-call'}),
      );

      await _pumpWizard(tester, api: _apiWith(adapter));

      // The count field used a controller rebuilt every frame, so what was
      // typed here never reached the payload.
      await tester.enterText(find.byType(TextField).first, '3');
      await tester.pump();

      await tester.tap(find.text('Create scheduling page'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final body = jsonDecode(adapter.bodies.single) as Map<String, dynamic>;
      expect(body['reminderEmails'], [
        {'value': 3, 'unit': 'day'},
      ]);
    });

    testWidgets('the save button is locked while the request is in flight',
        (tester) async {
      final adapter = _StubAdapter(
        savedBody: jsonEncode({'id': 'srv-4', 'name': 'Intro call', 'slug': '/intro-call'}),
        saveDelay: const Duration(seconds: 2),
      );

      await _pumpWizard(tester, api: _apiWith(adapter));

      await tester.tap(find.text('Create scheduling page'));
      await tester.pump();

      // Disabled and showing a spinner, so a second tap cannot fire a second
      // create request.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(adapter.calls.where((c) => c.startsWith('POST')).length, 1);
    });
  });

  group('the list is server-authoritative', () {
    test('a reload replaces the list with what the API returns', () async {
      final adapter = _StubAdapter(savedBody: '{}');
      final provider = MeetingSchedulerProvider(apiService: _apiWith(adapter));

      // Something only in local state — the shape of the old fake save.
      provider.addOrUpdateScheduler(_existing('local-only'));
      expect(provider.schedulers.map((s) => s.id), ['local-only']);

      await provider.fetchMeetingSchedulers();

      // The GET runs again and anything the server does not have is dropped,
      // which is exactly why a fake-saved page vanished on refresh.
      expect(adapter.calls, contains('GET /meeting-schedulers'));
      expect(provider.schedulers, isEmpty);
      expect(provider.error, isNull);
    });
  });

  group('editing an existing scheduling page', () {
    testWidgets('updates it instead of creating a duplicate', (tester) async {
      final adapter = _StubAdapter(
        savedBody: jsonEncode({'id': 's-1', 'name': 'Intro call', 'slug': '/intro-call'}),
      );

      await _pumpWizard(tester, api: _apiWith(adapter), isEditMode: true);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(adapter.calls, contains('PATCH /meeting-schedulers/s-1'));
      expect(adapter.calls.any((c) => c.startsWith('POST')), isFalse);
    });
  });

  group('a slow save', () {
    testWidgets('is not abandoned after a few seconds', (tester) async {
      // The old code gave up at 4s and then reported success anyway.
      final adapter = _StubAdapter(
        savedBody: jsonEncode({'id': 'srv-2', 'name': 'Intro call', 'slug': '/intro-call'}),
        saveDelay: const Duration(seconds: 6),
      );

      final wizard = await _pumpWizard(tester, api: _apiWith(adapter));
      await tester.tap(find.text('Create scheduling page'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();

      expect(adapter.calls, contains('POST /meeting-schedulers'));
      expect(find.textContaining('Could not create'), findsNothing);
      expect(wizard.closed, isTrue);
      expect(wizard.value, isNotNull);
    });
  });
}
