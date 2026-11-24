import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hrms/core/config/app_config.dart';
import 'package:hrms/core/utils/company_time.dart';
import 'package:hrms/data/local/hrms_local_data_source.dart';
import 'package:hrms/data/models/attendance_event_model.dart';
import 'package:hrms/features/attendance/services/attendance_service.dart';
import 'package:hrms/features/attendance/services/location_service.dart';
DateTime _testNow = DateTime.utc(2026, 11, 24, 3, 0);

void main() {
  test('company day follows configured Asia/Kolkata boundary', () {
    expect(
      companyCalendarDate(DateTime.utc(2026, 11, 23, 18, 29)),
      DateTime(2026, 11, 23),
    );
    expect(
      companyCalendarDate(DateTime.utc(2026, 11, 23, 18, 30)),
      DateTime(2026, 11, 24),
    );
  });

  test('attendance timestamps serialize as UTC and preserve the instant', () {
    final event = _event(
      id: 'utc-round-trip',
      type: AttendanceEventType.checkIn,
      timestamp: DateTime.utc(2026, 11, 23, 18, 30),
    );

    final json = event.toJson();
    final decoded = AttendanceEventModel.fromJson(json);

    expect(json['timestamp'], '2026-11-23T18:30:00.000Z');
    expect(decoded.timestamp.toUtc(), event.timestamp.toUtc());
  });

  test('check-out without a valid check-in is rejected', () async {
    final local = _FakeLocal();
    final service = _service(local);

    await expectLater(service.checkOut(), throwsA(isA<AttendanceException>()));
    expect(local.events, isEmpty);
  });

  test('a rejected check-in does not block a replacement check-in', () async {
    final local = _FakeLocal([
      _event(
        id: 'rejected-check-in',
        type: AttendanceEventType.checkIn,
        timestamp: _testNow,
        status: AttendanceSyncStatus.rejected,
      ),
    ]);

    final replacement = await _service(local).checkIn();

    expect(replacement.syncStatus, AttendanceSyncStatus.pending);
    expect(local.events, hasLength(2));
  });

  test('a rejected check-in does not authorize check-out', () async {
    final local = _FakeLocal([
      _event(
        id: 'rejected-check-in',
        type: AttendanceEventType.checkIn,
        timestamp: _testNow,
        status: AttendanceSyncStatus.rejected,
      ),
    ]);

    await expectLater(
      _service(local).checkOut(),
      throwsA(isA<AttendanceException>()),
    );
    expect(local.events, hasLength(1));
  });

  test('a Pending check-in permits immediate check-out', () async {
    final local = _FakeLocal();
    final service = _service(local);

    final checkIn = await service.checkIn();
    final checkOut = await service.checkOut();

    expect(checkIn.syncStatus, AttendanceSyncStatus.pending);
    expect(checkOut.type, AttendanceEventType.checkOut);
    expect(local.events, hasLength(2));
  });

  test(
    'Pending check-in blocks duplicates and only one check-out is allowed',
    () async {
      final local = _FakeLocal();
      final service = _service(local);

      await service.checkIn();
      await expectLater(service.checkIn(), throwsA(isA<AttendanceException>()));
      await service.checkOut();
      await expectLater(
        service.checkOut(),
        throwsA(isA<AttendanceException>()),
      );
      expect(local.events, hasLength(2));
    },
  );
  test('allows check-in after company midnight, even if UTC date differs', () async {
  final local = _FakeLocal([
    _event(
      id: 'previous-day-check-in',
      type: AttendanceEventType.checkIn,
      timestamp: DateTime.utc(2026, 11, 23, 18, 0),
    ),
    _event(
      id: 'previous-day-check-out',
      type: AttendanceEventType.checkOut,
      timestamp: DateTime.utc(2026, 11, 23, 18, 20),
    ),
  ]);

  final service = AttendanceService(
    localDataSource: local,
    locationService: LocationService(
      platform: _FakeLocationPlatform(),
    ),
    clock: () => DateTime.utc(2026, 11, 23, 18, 30),
  );

  final event = await service.checkIn();

  expect(event.type, AttendanceEventType.checkIn);
  expect(
    companyCalendarDate(event.timestamp),
    DateTime(2026, 11, 24),
  );
});
}

AttendanceService _service(_FakeLocal local) => AttendanceService(
  localDataSource: local,
  locationService: LocationService(platform: _FakeLocationPlatform()),
  clock: () => _testNow,
);

AttendanceEventModel _event({
  required String id,
  required AttendanceEventType type,
  required DateTime timestamp,
  AttendanceSyncStatus status = AttendanceSyncStatus.pending,
}) => AttendanceEventModel(
  id: id,
  employeeId: AppConfig.employeeId,
  type: type,
  timestamp: timestamp,
  latitude: AppConfig.officeLatitude,
  longitude: AppConfig.officeLongitude,
  syncStatus: status,
);

class _FakeLocal implements HrmsLocalDataSource {
  _FakeLocal([List<AttendanceEventModel>? initialEvents])
    : events = [...?initialEvents];

  final List<AttendanceEventModel> events;

  @override
  Future<List<AttendanceEventModel>> getAttendanceEvents({
    int? year,
    int? month,
  }) async => [...events];

  @override
  Future<void> saveAttendanceEvent(AttendanceEventModel event) async {
    events.add(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocationPlatform implements LocationPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings settings,
  }) async => Position(
    longitude: AppConfig.officeLongitude,
    latitude: AppConfig.officeLatitude,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
}
