
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrms/app.dart';
import 'package:hrms/core/services/connectivity_monitor.dart';
import 'package:hrms/core/theme/theme_controller.dart';
import 'package:hrms/data/local/hrms_local_data_source.dart';
import 'package:hrms/data/models/attendance_event_model.dart';
import 'package:hrms/data/models/employee_model.dart';
import 'package:hrms/data/models/leave_balance_model.dart';
import 'package:hrms/data/models/leave_request_model.dart';
import 'package:hrms/data/remote/hrms_remote_data_source.dart';
import 'package:hrms/data/repositories/employee_repository.dart';
import 'package:hrms/features/attendance/services/attendance_state.dart';
import 'package:hrms/features/leave/services/leave_service.dart';
import 'package:hrms/features/sync/services/attendance_sync_coordinator.dart';
import 'package:hrms/features/sync/services/attendance_sync_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Home renders employee data and pending sync state', (
    tester,
  ) async {
    final local = _FakeLocal();
    final remote = _FakeRemote();

    final connectivity = _FakeConnectivity()
      ..current = [ConnectivityResult.wifi];

    final monitor = ConnectivityMonitor(
      connectivity: connectivity,
    );

    final attendance = _TestAttendanceState(local, remote);

    final coordinator = AttendanceSyncCoordinator(
      connectivity: monitor,
      syncService: AttendanceSyncService(
        local: local,
        remote: remote,
      ),
      local: local,
    )
      ..pendingCount = 1
      ..syncedCount = 2;

    try {
      // Allow the connectivity monitor to finish initialization.
      await Future<void>.delayed(Duration.zero);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeController>(
              create: (_) => ThemeController(),
            ),
            Provider<EmployeeRepository>.value(
              value: _FakeEmployeeRepository(),
            ),
            ChangeNotifierProvider<AttendanceState>.value(
              value: attendance,
            ),
            ChangeNotifierProvider<ConnectivityMonitor>.value(
              value: monitor,
            ),
            Provider<LeaveService>.value(
              value: LeaveService(
                localDataSource: local,
                remoteDataSource: remote,
                isOnline: () async => true,
              ),
            ),
            ChangeNotifierProvider<AttendanceSyncCoordinator>.value(
              value: coordinator,
            ),
          ],
          child: const RebsHrmsApp(),
        ),
      );

      // Render the first frame and allow the dashboard animations to progress.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Your Overview'), findsOneWidget);
      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.text('1 Pending · 2 Synced'), findsOneWidget);
      expect(find.text('Pending Sync'), findsOneWidget);
    } finally {
      // Unmount widgets first so their timers and animations are disposed.
      await tester.pumpWidget(const SizedBox.shrink());

      coordinator.dispose();
      attendance.dispose();
      monitor.dispose();

      await connectivity.controller.close();
    }
  });
}

class _TestAttendanceState extends AttendanceState {
  _TestAttendanceState(
    super.local,
    super.remote,
  );

  @override
  Future<void> refresh({
    int? year,
    int? month,
    bool fetchRemote = true,
  }) {
    // Dashboard widget tests use local data only.
    return super.refresh(
      year: year,
      month: month,
      fetchRemote: false,
    );
  }
}

class _FakeEmployeeRepository implements EmployeeRepository {
  @override
  Future<EmployeeModel> getEmployee() async {
    return const EmployeeModel(
      id: 'REBS-1024',
      name: 'Alex Morgan',
      department: 'Engineering',
      designation: 'Developer',
      email: 'alex@example.invalid',
    );
  }
}

class _FakeLocal implements HrmsLocalDataSource {
  final List<AttendanceEventModel> events = [];

  LeaveBalanceModel balance = const LeaveBalanceModel(
    casualLeave: 8,
    sickLeave: 8,
  );

  @override
  Future<List<AttendanceEventModel>> getAttendanceEvents({
    int? year,
    int? month,
  }) async {
    return [...events];
  }

  @override
  Future<List<AttendanceEventModel>> getPendingAttendanceEvents() async {
    return events
        .where(
          (event) =>
              event.syncStatus == AttendanceSyncStatus.pending,
        )
        .toList();
  }

  @override
  Future<void> saveAttendanceEvent(
    AttendanceEventModel event,
  ) async {
    events.add(event);
  }

  @override
  Future<void> updateAttendanceStatus(
    String eventId,
    AttendanceSyncStatus status,
  ) async {
    final index = events.indexWhere(
      (event) => event.id == eventId,
    );

    if (index < 0) return;

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
  Future<LeaveBalanceModel?> getLeaveBalance() async {
    return balance;
  }

  @override
  Future<void> saveLeaveBalance(
    LeaveBalanceModel value,
  ) async {
    balance = value;
  }

  @override
  Future<void> saveLeaveRequest(
    LeaveRequestModel request,
  ) async {}

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests() async {
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeRemote implements HrmsRemoteDataSource {
  @override
  Future<List<AttendanceEventModel>> getAttendance({
    required int year,
    required int month,
  }) async {
    return const [];
  }

  @override
  Future<LeaveBalanceModel> getLeaveBalance() async {
    return const LeaveBalanceModel(
      casualLeave: 8,
      sickLeave: 8,
    );
  }

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests() async {
    return const [];
  }

  @override
  Future<AttendanceEventModel> submitAttendanceEvent(
    AttendanceEventModel event,
  ) async {
    return event;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeConnectivity implements Connectivity {
  final StreamController<List<ConnectivityResult>> controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  List<ConnectivityResult> current = [
    ConnectivityResult.none,
  ];

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return current;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
