import 'package:sqflite/sqflite.dart';

import '../../core/utils/company_time.dart';
import '../models/employee_model.dart';
import '../models/attendance_event_model.dart';
import '../models/leave_balance_model.dart';
import '../models/leave_request_model.dart';
import 'app_database.dart';

class HrmsLocalDataSource {
  HrmsLocalDataSource({AppDatabase? database})
    : _databaseProvider = database ?? AppDatabase.instance;

  final AppDatabase _databaseProvider;

  Future<Database> get _db => _databaseProvider.database;

  // EMPLOYEE

  Future<void> saveEmployee(EmployeeModel employee) async {
    final db = await _db;

    await db.insert(
      'employee',
      employee.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<EmployeeModel?> getEmployee() async {
    final db = await _db;
    final rows = await db.query('employee', limit: 1);

    if (rows.isEmpty) return null;

    return EmployeeModel.fromJson(rows.first);
  }

  // ATTENDANCE

  Future<void> saveAttendanceEvent(AttendanceEventModel event) async {
    final db = await _db;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'attendance_events',
        where: 'id = ?',
        whereArgs: [event.id],
        limit: 1,
      );

      if (existing.isNotEmpty) return;

      final nextOrder =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COALESCE(MAX(created_order), 0) + 1 '
              'FROM attendance_events',
            ),
          ) ??
          1;

      await txn.insert('attendance_events', {
        'id': event.id,
        'employee_id': event.employeeId,
        'type': event.type == AttendanceEventType.checkIn
            ? 'check_in'
            : 'check_out',
        'timestamp': event.timestamp.toUtc().toIso8601String(),
        'latitude': event.latitude,
        'longitude': event.longitude,
        'sync_status': event.syncStatus.name,
        'created_order': nextOrder,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    });
  }

  Future<List<AttendanceEventModel>> getAttendanceEvents({
    int? year,
    int? month,
  }) async {
    final db = await _db;

    final rows = await db.query(
      'attendance_events',
      orderBy: 'created_order ASC',
    );

    final events = rows.map((row) {
      return AttendanceEventModel.fromJson({
        'id': row['id'],
        'employeeId': row['employee_id'],
        'type': row['type'],
        'timestamp': row['timestamp'],
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'syncStatus': row['sync_status'],
      });
    }).toList();

    if (year == null || month == null) return events;
    return events.where((event) {
      final companyDate = companyCalendarDate(event.timestamp);
      return companyDate.year == year && companyDate.month == month;
    }).toList();
  }

  Future<List<AttendanceEventModel>> getPendingAttendanceEvents() async {
    final db = await _db;

    final rows = await db.query(
      'attendance_events',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_order ASC',
    );

    return rows.map((row) {
      return AttendanceEventModel.fromJson({
        'id': row['id'],
        'employeeId': row['employee_id'],
        'type': row['type'],
        'timestamp': row['timestamp'],
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'syncStatus': row['sync_status'],
      });
    }).toList();
  }

  Future<void> updateAttendanceStatus(
    String eventId,
    AttendanceSyncStatus status,
  ) async {
    final db = await _db;

    await db.update(
      'attendance_events',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  // LEAVE BALANCE

  Future<void> saveLeaveBalance(LeaveBalanceModel balance) async {
    final db = await _db;

    await db.insert('leave_balance', {
      'id': 1,
      'casual_leave': balance.casualLeave,
      'sick_leave': balance.sickLeave,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<LeaveBalanceModel?> getLeaveBalance() async {
    final db = await _db;
    final rows = await db.query(
      'leave_balance',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return LeaveBalanceModel.fromJson({
      'casualLeave': rows.first['casual_leave'],
      'sickLeave': rows.first['sick_leave'],
    });
  }

  // LEAVE REQUESTS

  Future<void> saveLeaveRequest(LeaveRequestModel request) async {
    final db = await _db;

    await db.insert('leave_requests', {
      'id': request.id,
      'employee_id': request.employeeId,
      'type': request.type.name,
      'start_date': request.startDate.toIso8601String(),
      'end_date': request.endDate.toIso8601String(),
      'reason': request.reason,
      'status': request.status.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LeaveRequestModel>> getLeaveRequests() async {
    final db = await _db;

    final rows = await db.query('leave_requests', orderBy: 'start_date DESC');

    return rows.map((row) {
      return LeaveRequestModel.fromJson({
        'id': row['id'],
        'employeeId': row['employee_id'],
        'type': row['type'],
        'startDate': row['start_date'],
        'endDate': row['end_date'],
        'reason': row['reason'],
        'status': row['status'],
      });
    }).toList();
  }

  Future<void> updateLeaveRequestStatus(
    String requestId,
    LeaveRequestStatus status,
  ) async {
    final db = await _db;

    await db.update(
      'leave_requests',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }
}
