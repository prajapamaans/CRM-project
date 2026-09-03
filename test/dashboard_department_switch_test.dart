import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:crmproject/core/utils/department_scope.dart';
import 'package:crmproject/core/utils/task_query_builder.dart';
import 'package:crmproject/features/dashboard/data/models/activity_stats_model.dart';
import 'package:crmproject/features/dashboard/data/models/dashboard_unified_model.dart';
import 'package:crmproject/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:crmproject/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:crmproject/features/departments/presentation/providers/department_provider.dart';

/// The departments the backend returns from `GET /api/departments`. Read from
/// the app's own constants rather than written out here, and treated as just
/// two of many — nothing below is keyed to either one.
final apacId = DepartmentConstants.apacId;
final australiaId = DepartmentConstants.australiaId;
const newerDepartmentId = 'a1b2c3d4-0000-0000-0000-00000000009f';

/// A stats repository whose answers can be held open, so a switch can happen
/// while a request for the previous department is still in the air.
class _SlowRepository implements DashboardRepository {
  final Map<String, Completer<ActivityStatsModel>> pending = {};
  final List<String?> statsRequests = [];

  @override
  Future<ActivityStatsModel> getActivityStats({
    String? ownerId,
    String? departmentId,
    String? startDate,
    String? endDate,
  }) {
    statsRequests.add(departmentId);
    final completer = Completer<ActivityStatsModel>();
    pending[departmentId ?? ''] = completer;
    return completer.future;
  }

  /// Answers the request that was made for [departmentId].
  void answer(String departmentId, int totalActivities) {
    pending[departmentId]!.complete(
      ActivityStatsModel.fromJson({'totalActivities': totalActivities}),
    );
  }

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

void main() {
  group('a response may only land on the department it was asked for', () {
    test('the newest request for a department wins', () {
      final guard = DepartmentRequestGuard();

      final first = guard.begin('stats', apacId);
      final second = guard.begin('stats', apacId);

      expect(guard.mayApply('stats', first, apacId), isFalse);
      expect(guard.mayApply('stats', second, apacId), isTrue);
    });

    test('an answer for the department just left is refused', () {
      final guard = DepartmentRequestGuard();

      final apacTicket = guard.begin('stats', apacId);
      // The user switches while APAC is still loading.
      final australiaTicket = guard.begin('stats', australiaId);

      expect(guard.mayApply('stats', apacTicket, apacId), isFalse);
      expect(guard.mayApply('stats', australiaTicket, australiaId), isTrue);
    });

    test('one section reloading does not discard another section in flight', () {
      final guard = DepartmentRequestGuard();

      final statsTicket = guard.begin('stats', apacId);
      guard.begin('tasks', apacId);

      expect(guard.mayApply('stats', statsTicket, apacId), isTrue);
    });

    test('switching back and forth keeps answering the department on screen', () {
      final guard = DepartmentRequestGuard();

      final apacFirst = guard.begin('stats', apacId);
      final australia = guard.begin('stats', australiaId);
      final apacAgain = guard.begin('stats', apacId);

      expect(guard.mayApply('stats', apacFirst, apacId), isFalse);
      expect(guard.mayApply('stats', australia, australiaId), isFalse);
      expect(guard.mayApply('stats', apacAgain, apacId), isTrue);
    });

    test('works the same for a department the app has never heard of', () {
      final guard = DepartmentRequestGuard();

      final stale = guard.begin('stats', apacId);
      final current = guard.begin('stats', newerDepartmentId);

      expect(guard.mayApply('stats', stale, apacId), isFalse);
      expect(guard.mayApply('stats', current, newerDepartmentId), isTrue);
    });

    test('dropping cached data abandons everything already asked for', () {
      final guard = DepartmentRequestGuard();
      final ticket = guard.begin('stats', apacId);

      guard.abandonAll();

      expect(guard.mayApply('stats', ticket, apacId), isFalse);
    });

    test('the Tasks screen and the Dashboard apply the same rule', () {
      // Same inputs, same verdict — one rule, two screens.
      for (final (responseSeq, latestSeq, requested, selected) in [
        (1, 1, apacId, apacId),
        (1, 2, apacId, apacId),
        (1, 1, apacId, australiaId),
      ]) {
        expect(
          shouldApplyTaskResponse(
            responseSeq: responseSeq,
            latestSeq: latestSeq,
            requestedDepartmentId: requested,
            selectedDepartmentId: selected,
          ),
          mayApplyDepartmentResponse(
            responseSeq: responseSeq,
            latestSeq: latestSeq,
            requestedDepartmentId: requested,
            selectedDepartmentId: selected,
          ),
        );
      }
    });
  });

  group('the Dashboard provider', () {
    test('asks for the department it was given, whichever one that is', () async {
      final repo = _SlowRepository();
      final provider = DashboardProvider(repository: repo);

      for (final departmentId in [apacId, australiaId, newerDepartmentId]) {
        final inFlight = provider.fetchActivityStats(departmentId: departmentId);
        repo.answer(departmentId, 1);
        await inFlight;
      }

      expect(repo.statsRequests, [apacId, australiaId, newerDepartmentId]);
    });

    test('a slow answer for the previous department cannot overwrite the new one',
        () async {
      final repo = _SlowRepository();
      final provider = DashboardProvider(repository: repo);

      // APAC starts loading.
      final apacInFlight = provider.fetchActivityStats(departmentId: apacId);
      // The user switches to Australia before it comes back.
      final australiaInFlight =
          provider.fetchActivityStats(departmentId: australiaId);

      // Australia answers first, then the stale APAC request finally lands.
      repo.answer(australiaId, 42);
      await australiaInFlight;
      repo.answer(apacId, 7);
      await apacInFlight;

      // Australia's data survives. APAC's is discarded, not shown under it.
      expect(provider.stats?.totalActivities, 42);
      expect(provider.isLoadingStats, isFalse);
    });

    test('a stale answer does not clear the loading flag of the live request',
        () async {
      final repo = _SlowRepository();
      final provider = DashboardProvider(repository: repo);

      final apacInFlight = provider.fetchActivityStats(departmentId: apacId);
      final australiaInFlight =
          provider.fetchActivityStats(departmentId: australiaId);

      repo.answer(apacId, 7);
      await apacInFlight;

      // Australia is still running, so the Dashboard must still read as loading.
      expect(provider.isLoadingStats, isTrue);
      expect(provider.stats, isNull);

      repo.answer(australiaId, 42);
      await australiaInFlight;

      expect(provider.isLoadingStats, isFalse);
      expect(provider.stats?.totalActivities, 42);
    });

    test('clearing drops the previous department\'s tasks, not just its stats',
        () {
      final provider = DashboardProvider(repository: _SlowRepository());
      provider.dashboardTasks.addAll([
        {'id': 'apac-task', 'title': 'APAC only', 'status': 'pending'},
      ]);

      provider.clearData();

      // The three work cards read from this list. It used to survive a switch,
      // leaving APAC's tasks on screen under the new department's name.
      expect(provider.dashboardTasks, isEmpty);
      expect(provider.isLoadingTasks, isFalse);
      expect(provider.tasksError, isNull);
    });

    test('an answer already in flight cannot refill what clearing emptied',
        () async {
      final repo = _SlowRepository();
      final provider = DashboardProvider(repository: repo);

      final inFlight = provider.fetchActivityStats(departmentId: apacId);
      provider.clearData();
      repo.answer(apacId, 7);
      await inFlight;

      expect(provider.stats, isNull);
    });
  });
}
