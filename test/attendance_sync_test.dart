import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrms/core/services/connectivity_monitor.dart';
import 'package:hrms/data/local/hrms_local_data_source.dart';
import 'package:hrms/data/models/attendance_event_model.dart';
import 'package:hrms/data/remote/hrms_remote_data_source.dart';
import 'package:hrms/features/sync/services/attendance_sync_coordinator.dart';
import 'package:hrms/features/sync/services/attendance_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pending events sync in created order and become synced', () async {
    final local = _FakeLocal([_event('first'), _event('second')]);
    final remote = _FakeRemote();
    final result = await AttendanceSyncService(
      local: local,
      remote: remote,
    ).syncPendingEvents();

    expect(remote.ids, ['first', 'second']);
    expect(result.synced, 2);
    expect(result.remaining, 0);
    expect(
      local.events.every((e) => e.syncStatus == AttendanceSyncStatus.synced),
      isTrue,
    );
  });

  test(
    'post-attendance trigger uses shared sync service when online',
    () async {
      final connectivity = _FakeConnectivity()
        ..current = [ConnectivityResult.wifi];
      final monitor = ConnectivityMonitor(connectivity: connectivity);
      await Future<void>.delayed(Duration.zero);
      final local = _FakeLocal([_event('after-attendance')]);
      final remote = _FakeRemote();
      final coordinator = AttendanceSyncCoordinator(
        connectivity: monitor,
        syncService: AttendanceSyncService(local: local, remote: remote),
        local: local,
      );

      await coordinator.syncPendingEventsIfConnected();

      expect(remote.ids, ['after-attendance']);
      expect(local.events.single.syncStatus, AttendanceSyncStatus.synced);
      expect(coordinator.syncedCount, 1);
      coordinator.dispose();
      monitor.dispose();
      await connectivity.controller.close();
    },
  );

  test('post-attendance trigger syncs immediately when connected', () async {
    final connectivity = _FakeConnectivity()
      ..current = [ConnectivityResult.wifi];
    final monitor = ConnectivityMonitor(connectivity: connectivity);
    await Future<void>.delayed(Duration.zero);
    final local = _FakeLocal([_event('saved-check-in')]);
    final remote = _FakeRemote();
    final coordinator = AttendanceSyncCoordinator(
      connectivity: monitor,
      syncService: AttendanceSyncService(local: local, remote: remote),
      local: local,
    );

    await coordinator.syncPendingEventsIfConnected();

    expect(remote.ids, ['saved-check-in']);
    expect(local.events.single.syncStatus, AttendanceSyncStatus.synced);
    expect(coordinator.syncedCount, 1);
    coordinator.dispose();
    monitor.dispose();
    await connectivity.controller.close();
  });

  test(
    'temporary request failure retains event ID and pending status for retry',
    () async {
      final local = _FakeLocal([_event('stable-id')]);
      final remote = _FakeRemote()..failNext = true;
      final service = AttendanceSyncService(local: local, remote: remote);

      final failed = await service.syncPendingEvents();
      expect(failed.remaining, 1);
      expect(local.events.single.syncStatus, AttendanceSyncStatus.pending);

      final retried = await service.syncPendingEvents();
      expect(remote.ids, ['stable-id', 'stable-id']);
      expect(retried.synced, 1);
      expect(local.events.single.syncStatus, AttendanceSyncStatus.synced);
    },
  );

  test(
    'connectivity restoration triggers one sync and updates status',
    () async {
      final connectivity = _FakeConnectivity();
      final monitor = ConnectivityMonitor(connectivity: connectivity);
      await Future<void>.delayed(Duration.zero);
      final local = _FakeLocal([_event('auto')]);
      final remote = _FakeRemote()..hold = Completer<void>();
      final sync = AttendanceSyncService(local: local, remote: remote);
      final coordinator = AttendanceSyncCoordinator(
        connectivity: monitor,
        syncService: sync,
        local: local,
      )..start();
      await coordinator.refreshCounts();

      connectivity.emit([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      connectivity.emit([ConnectivityResult.mobile]);
      final manual = coordinator.syncPendingEvents();
      expect(remote.ids, ['auto']);
      remote.hold!.complete();
      await manual;
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(remote.ids, ['auto']);
      expect(coordinator.pendingCount, 0);
      expect(coordinator.syncedCount, 1);
      coordinator.dispose();
      monitor.dispose();
      await connectivity.controller.close();
    },
  );

  test(
    'offline coordinator retains events without calling the server',
    () async {
      final connectivity = _FakeConnectivity();
      final monitor = ConnectivityMonitor(connectivity: connectivity);
      await Future<void>.delayed(Duration.zero);
      final local = _FakeLocal([_event('offline')]);
      final remote = _FakeRemote();
      final coordinator = AttendanceSyncCoordinator(
        connectivity: monitor,
        syncService: AttendanceSyncService(local: local, remote: remote),
        local: local,
      )..start();
      await coordinator.refreshCounts();

      await coordinator.syncPendingEvents();

      expect(local.events.single.syncStatus, AttendanceSyncStatus.pending);
      expect(remote.ids, isEmpty);
      expect(coordinator.lastError, contains('offline'));
      coordinator.dispose();
      monitor.dispose();
      await connectivity.controller.close();
    },
  );
}

AttendanceEventModel _event(String id) => AttendanceEventModel(
  id: id,
  employeeId: 'employee',
  type: AttendanceEventType.checkIn,
  timestamp: DateTime(2026, 11, 24, 9),
  latitude: 0,
  longitude: 0,
);

class _FakeLocal implements HrmsLocalDataSource {
  _FakeLocal(this.events);
  final List<AttendanceEventModel> events;

  @override
  Future<List<AttendanceEventModel>> getPendingAttendanceEvents() async =>
      events
          .where((e) => e.syncStatus == AttendanceSyncStatus.pending)
          .toList();

  @override
  Future<List<AttendanceEventModel>> getAttendanceEvents({
    int? year,
    int? month,
  }) async => events;

  @override
  Future<void> updateAttendanceStatus(
    String eventId,
    AttendanceSyncStatus status,
  ) async {
    final index = events.indexWhere((e) => e.id == eventId);
    final old = events[index];
    events[index] = AttendanceEventModel(
      id: old.id,
      employeeId: old.employeeId,
      type: old.type,
      timestamp: old.timestamp,
      latitude: old.latitude,
      longitude: old.longitude,
      syncStatus: status,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRemote implements HrmsRemoteDataSource {
  final List<String> ids = [];
  bool failNext = false;
  Completer<void>? hold;

  @override
  Future<AttendanceEventModel> submitAttendanceEvent(
    AttendanceEventModel event,
  ) async {
    ids.add(event.id);
    if (hold != null) await hold!.future;
    if (failNext) {
      failNext = false;
      throw Exception('simulated offline request');
    }
    return event;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConnectivity implements Connectivity {
  final StreamController<List<ConnectivityResult>> controller =
      StreamController.broadcast();
  List<ConnectivityResult> current = [ConnectivityResult.none];

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      controller.stream;

  void emit(List<ConnectivityResult> value) {
    current = value;
    controller.add(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
