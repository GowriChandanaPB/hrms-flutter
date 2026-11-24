import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrms/core/config/app_config.dart';
import 'package:hrms/core/utils/calendar_date.dart';
import 'package:hrms/data/local/hrms_local_data_source.dart';
import 'package:hrms/data/models/leave_balance_model.dart';
import 'package:hrms/data/models/leave_request_model.dart';
import 'package:hrms/data/remote/hrms_remote_data_source.dart';
import 'package:hrms/features/leave/services/leave_service.dart';
import 'package:hrms/features/leave/services/leave_validation.dart';

void main() {
  group('LeaveValidation', () {
    test('company date uses Asia/Kolkata rather than device local date', () {
      expect(
        LeaveValidation.companyToday(DateTime.utc(2026, 1, 1, 20)),
        DateTime(2026, 1, 2),
      );
    });

    test('accepts exactly 10 non-whitespace reason characters', () {
      expect(LeaveValidation.reasonError(' abcde fghij '), isNull);
      expect(LeaveValidation.normalizeReason(' abcde fghij '), 'abcde fghij');
    });

    test('rejects fewer than 10 and whitespace-only reasons', () {
      expect(LeaveValidation.reasonError('abcdefghi'), isNotNull);
      expect(LeaveValidation.reasonError('   \n\t  '), isNotNull);
    });

    test('counts calendar days inclusively, including weekends', () {
      expect(
        LeaveValidation.requestedDays(
          DateTime(2026, 1, 3),
          DateTime(2026, 1, 5),
        ),
        3,
      );
      expect(
        LeaveValidation.requestedDays(
          DateTime(2026, 1, 3),
          DateTime(2026, 1, 4),
        ),
        2,
      );
    });

    test('overlap is inclusive and only Pending or Approved block', () {
      final start = DateTime(2026, 2, 1);
      final end = DateTime(2026, 2, 3);

      for (final status in [
        LeaveRequestStatus.pending,
        LeaveRequestStatus.approved,
      ]) {
        expect(
          LeaveValidation.overlapsActiveRequest(
            startDate: end,
            endDate: DateTime(2026, 2, 4),
            requests: [_request('active', start, end, status)],
            employeeId: AppConfig.employeeId,
          ),
          isTrue,
        );
      }

      expect(
        LeaveValidation.overlapsActiveRequest(
          startDate: end,
          endDate: DateTime(2026, 2, 4),
          requests: [
            _request('rejected', start, end, LeaveRequestStatus.rejected),
          ],
          employeeId: AppConfig.employeeId,
        ),
        isFalse,
      );
    });

    test('date-only model serialization round-trips without timezone shifts', () {
      final request = _request(
        'round-trip',
        DateTime(2026, 12, 31, 23, 45),
        DateTime(2027, 1, 2, 8),
        LeaveRequestStatus.pending,
      );
      final decoded = LeaveRequestModel.fromJson(request.toJson());

      expect(request.toJson()['startDate'], '2026-12-31');
      expect(request.toJson()['endDate'], '2027-01-02');
      expect(calendarDateString(decoded.startDate), '2026-12-31');
      expect(calendarDateString(decoded.endDate), '2027-01-02');
    });
  });

  group('LeaveService', () {
    test('rejects a start date before the company date', () async {
      final service = _service();
      await expectLater(
        _submit(service, start: DateTime(2025, 12, 31)),
        throwsA(
          isA<LeaveException>().having(
            (error) => error.field,
            'field',
            LeaveValidationField.startDate,
          ),
        ),
      );
    });

    test('rejects an end date before the start date', () async {
      final service = _service();
      await expectLater(
        _submit(
          service,
          start: DateTime(2026, 1, 3),
          end: DateTime(2026, 1, 2),
        ),
        throwsA(isA<LeaveException>()),
      );
    });

    test('accepts an exactly 10-character reason', () async {
      final remote = _FakeRemote();
      final request = await _submit(_service(remote: remote), reason: '0123456789');
      expect(request.reason, '0123456789');
      expect(remote.submitCount, 1);
    });

    test('rejects fewer than 10 non-whitespace reason characters', () async {
      await expectLater(
        _submit(_service(), reason: '123456789'),
        throwsA(isA<LeaveException>()),
      );
    });

    test('rejects a whitespace-only reason', () async {
      await expectLater(
        _submit(_service(), reason: ' \n   \t '),
        throwsA(isA<LeaveException>()),
      );
    });

    test('rejects requests exceeding Casual Leave balance', () async {
      final remote = _FakeRemote(
        balance: const LeaveBalanceModel(casualLeave: 1, sickLeave: 8),
      );
      await expectLater(
        _submit(
          _service(remote: remote),
          end: DateTime(2026, 1, 2),
        ),
        throwsA(isA<LeaveException>()),
      );
      expect(remote.submitCount, 0);
    });

    test('rejects requests exceeding Sick Leave balance', () async {
      final remote = _FakeRemote(
        balance: const LeaveBalanceModel(casualLeave: 8, sickLeave: 1),
      );
      await expectLater(
        _submit(
          _service(remote: remote),
          type: LeaveType.sick,
          end: DateTime(2026, 1, 2),
        ),
        throwsA(isA<LeaveException>()),
      );
      expect(remote.submitCount, 0);
    });

    test('rejects overlap with a Pending request saved in SQLite', () async {
      final local = _FakeLocal(
        requests: [
          _request(
            'local-pending',
            DateTime(2026, 1, 3),
            DateTime(2026, 1, 4),
            LeaveRequestStatus.pending,
          ),
        ],
      );
      await expectLater(
        _submit(_service(local: local), start: DateTime(2026, 1, 4)),
        throwsA(isA<LeaveException>()),
      );
    });

    test('rejects overlap with an Approved request returned by the API', () async {
      final remote = _FakeRemote(
        requests: [
          _request(
            'remote-approved',
            DateTime(2026, 1, 3),
            DateTime(2026, 1, 4),
            LeaveRequestStatus.approved,
          ),
        ],
      );
      await expectLater(
        _submit(_service(remote: remote), start: DateTime(2026, 1, 4)),
        throwsA(isA<LeaveException>()),
      );
    });

    test('allows dates overlapping only a Rejected request', () async {
      final local = _FakeLocal(
        requests: [
          _request(
            'local-rejected',
            DateTime(2026, 1, 3),
            DateTime(2026, 1, 4),
            LeaveRequestStatus.rejected,
          ),
        ],
      );
      final result = await _submit(
        _service(local: local),
        start: DateTime(2026, 1, 4),
      );
      expect(result.status, LeaveRequestStatus.pending);
    });

    test('allows adjacent non-overlapping date ranges', () async {
      final remote = _FakeRemote(
        requests: [
          _request(
            'adjacent',
            DateTime(2026, 1, 2),
            DateTime(2026, 1, 4),
            LeaveRequestStatus.pending,
          ),
        ],
      );
      final result = await _submit(
        _service(remote: remote),
        start: DateTime(2026, 1, 5),
      );
      expect(result.status, LeaveRequestStatus.pending);
    });

    test('prevents a second submit while the first is processing', () async {
      final remote = _FakeRemote()
        ..submissionGate = Completer<void>()
        ..submissionStarted = Completer<void>();
      final service = _service(remote: remote);
      final first = _submit(service);
      await remote.submissionStarted!.future;

      await expectLater(
        _submit(service),
        throwsA(isA<LeaveException>()),
      );
      remote.submissionGate!.complete();
      await first;
      expect(remote.submitCount, 1);
    });

    test('prevents offline submission without saving a request locally', () async {
      final local = _FakeLocal();
      final remote = _FakeRemote();
      final service = _service(
        local: local,
        remote: remote,
        online: false,
      );

      await expectLater(
        _submit(service),
        throwsA(
          isA<LeaveException>().having(
            (error) => error.field,
            'field',
            LeaveValidationField.connectivity,
          ),
        ),
      );
      expect(remote.submitCount, 0);
      expect(local.requests, isEmpty);
    });

    test('checks overlaps against both cache-only and server-only requests',
        () async {
      final local = _FakeLocal(
        requests: [
          _request(
            'sqlite-only',
            DateTime(2026, 2, 2),
            DateTime(2026, 2, 3),
            LeaveRequestStatus.pending,
          ),
        ],
      );
      final remote = _FakeRemote(
        requests: [
          _request(
            'server-only',
            DateTime(2026, 2, 5),
            DateTime(2026, 2, 6),
            LeaveRequestStatus.approved,
          ),
        ],
      );
      final service = _service(local: local, remote: remote);

      await expectLater(
        _submit(service, start: DateTime(2026, 2, 3)),
        throwsA(isA<LeaveException>()),
      );
      await expectLater(
        _submit(service, start: DateTime(2026, 2, 6)),
        throwsA(isA<LeaveException>()),
      );
    });
  });
}

LeaveService _service({
  _FakeLocal? local,
  _FakeRemote? remote,
  bool online = true,
}) =>
    LeaveService(
      localDataSource: local ?? _FakeLocal(),
      remoteDataSource: remote ?? _FakeRemote(),
      isOnline: () async => online,
      clock: () => DateTime.utc(2026, 1, 1, 6, 30),
    );

Future<LeaveRequestModel> _submit(
  LeaveService service, {
  LeaveType type = LeaveType.casual,
  DateTime? start,
  DateTime? end,
  String reason = 'A valid leave reason',
}) =>
    service.submitLeaveRequest(
      type: type,
      startDate: start ?? DateTime(2026, 1, 1),
      endDate: end ?? start ?? DateTime(2026, 1, 1),
      reason: reason,
    );

LeaveRequestModel _request(
  String id,
  DateTime start,
  DateTime end,
  LeaveRequestStatus status,
) =>
    LeaveRequestModel(
      id: id,
      employeeId: AppConfig.employeeId,
      type: LeaveType.casual,
      startDate: start,
      endDate: end,
      reason: 'Existing leave request',
      status: status,
    );

class _FakeLocal implements HrmsLocalDataSource {
  _FakeLocal({List<LeaveRequestModel> requests = const []})
    : requests = [...requests];

    LeaveBalanceModel? balance =
      const LeaveBalanceModel(casualLeave: 8, sickLeave: 8);
  final List<LeaveRequestModel> requests;

  @override
  Future<LeaveBalanceModel?> getLeaveBalance() async => balance;

  @override
  Future<void> saveLeaveBalance(LeaveBalanceModel value) async {
    balance = value;
  }

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests() async => [...requests];

  @override
  Future<void> saveLeaveRequest(LeaveRequestModel request) async {
    requests.removeWhere((item) => item.id == request.id);
    requests.add(request);
  }

  @override
  Future<void> updateLeaveRequestStatus(
    String requestId,
    LeaveRequestStatus status,
  ) async {
    final index = requests.indexWhere((item) => item.id == requestId);
    if (index >= 0) {
      final previous = requests[index];
      requests[index] = LeaveRequestModel(
        id: previous.id,
        employeeId: previous.employeeId,
        type: previous.type,
        startDate: previous.startDate,
        endDate: previous.endDate,
        reason: previous.reason,
        status: status,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRemote implements HrmsRemoteDataSource {
  _FakeRemote({
    this.balance = const LeaveBalanceModel(casualLeave: 8, sickLeave: 8),
    List<LeaveRequestModel> requests = const [],
  }) : requests = [...requests];

  LeaveBalanceModel balance;
  final List<LeaveRequestModel> requests;
  int submitCount = 0;
  Completer<void>? submissionGate;
  Completer<void>? submissionStarted;

  @override
  Future<LeaveBalanceModel> getLeaveBalance() async => balance;

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests() async => [...requests];

  @override
  Future<LeaveRequestModel> submitLeaveRequest(
    LeaveRequestModel request,
  ) async {
    submitCount++;
    submissionStarted?.complete();
    if (submissionGate != null) await submissionGate!.future;
    requests.add(request);
    return request;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}