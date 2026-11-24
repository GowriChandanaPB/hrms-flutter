
import '../models/attendance_event_model.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceEventModel>> getAttendance({
    required int year,
    required int month,
  });

  Future<void> submitAttendanceEvent(AttendanceEventModel event);
}
