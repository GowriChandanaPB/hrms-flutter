
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hrms/data/local/app_database.dart';
import 'package:hrms/data/local/hrms_local_data_source.dart';
import 'package:hrms/data/models/attendance_event_model.dart';

void main() {
  late Directory testDirectory;
  late AppDatabase database;
  late HrmsLocalDataSource local;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'rebs_hrms_test_',
    );

    final path = p.join(testDirectory.path, 'test_hrms.db');

    database = AppDatabase.forTesting(path);
    local = HrmsLocalDataSource(database: database);
  });

  tearDown(() async {
    await database.close();

    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('Pending attendance events survive database close and reopen', () async {
    final first = _event(
      id: 'event-001',
      timestamp: DateTime.utc(2026, 11, 24, 3),
    );

    final second = _event(
      id: 'event-002',
      timestamp: DateTime.utc(2026, 11, 24, 3, 5),
      type: AttendanceEventType.checkOut,
    );

    await local.saveAttendanceEvent(first);
    await local.saveAttendanceEvent(second);

    await database.close();

    final restored = await local.getPendingAttendanceEvents();

    expect(restored, hasLength(2));
    expect(restored[0].id, 'event-001');
    expect(restored[1].id, 'event-002');

    expect(
      restored.every(
        (event) => event.syncStatus == AttendanceSyncStatus.pending,
      ),
      isTrue,
    );

    expect(restored[0].timestamp.toUtc(), first.timestamp.toUtc());
    expect(restored[1].type, AttendanceEventType.checkOut);
  });

  test('Synced status survives database close and reopen', () async {
    final event = _event(id: 'synced-event');

    await local.saveAttendanceEvent(event);
    await local.updateAttendanceStatus(
      event.id,
      AttendanceSyncStatus.synced,
    );

    await database.close();

    final restored = await local.getAttendanceEvents();

    expect(restored, hasLength(1));
    expect(
      restored.first.syncStatus,
      AttendanceSyncStatus.synced,
    );
    expect(await local.getPendingAttendanceEvents(), isEmpty);
  });

  test('Rejected status survives database close and reopen', () async {
    final event = _event(id: 'rejected-event');

    await local.saveAttendanceEvent(event);
    await local.updateAttendanceStatus(
      event.id,
      AttendanceSyncStatus.rejected,
    );

    await database.close();

    final restored = await local.getAttendanceEvents();

    expect(restored, hasLength(1));
    expect(
      restored.first.syncStatus,
      AttendanceSyncStatus.rejected,
    );
    expect(await local.getPendingAttendanceEvents(), isEmpty);
  });

  test('Saving the same event ID does not create a duplicate', () async {
    final event = _event(id: 'duplicate-event');

    await local.saveAttendanceEvent(event);
    await local.saveAttendanceEvent(event);

    final events = await local.getAttendanceEvents();

    expect(events, hasLength(1));
    expect(events.single.id, event.id);
  });
}

AttendanceEventModel _event({
  required String id,
  DateTime? timestamp,
  AttendanceEventType type = AttendanceEventType.checkIn,
}) {
  return AttendanceEventModel(
    id: id,
    employeeId: 'REBS-1024',
    type: type,
    timestamp: timestamp ?? DateTime.utc(2026, 11, 24, 3),
    latitude: 12.915577,
    longitude: 77.628337,
    syncStatus: AttendanceSyncStatus.pending,
  );
}
