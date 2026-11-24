
import '../local/hrms_local_data_source.dart';
import '../models/attendance_event_model.dart';
import '../remote/hrms_remote_data_source.dart';
import 'attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final HrmsRemoteDataSource remote;
  final HrmsLocalDataSource local;

  AttendanceRepositoryImpl({
    required this.remote,
    required this.local,
  });

  @override
  Future<List<AttendanceEventModel>> getAttendance({
    required int year,
    required int month,
  }) async {
    try {
      final events = await remote.getAttendance(
        year: year,
        month: month,
      );

      for (final event in events) {
        await local.saveAttendanceEvent(event);
      }

      return events;
    } catch (_) {
      // Fall back to locally cached attendance when the API is unavailable.
      final cachedEvents = await local.getAttendanceEvents(
        year: year,
        month: month,
      );

      if (cachedEvents.isNotEmpty) {
        return cachedEvents;
      }

      rethrow;
    }
  }

  @override
  Future<AttendanceEventModel> submitAttendanceEvent(
    AttendanceEventModel event,
  ) {
    return remote.submitAttendanceEvent(event);
  }
}
