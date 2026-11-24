import 'package:dio/dio.dart';

import '../../../data/local/hrms_local_data_source.dart';
import '../../../data/models/attendance_event_model.dart';
import '../../../data/remote/hrms_remote_data_source.dart';

class AttendanceSyncResult {
  final int synced;
  final int rejected;
  final int remaining;
  final String? error;

  const AttendanceSyncResult({
    required this.synced,
    required this.rejected,
    required this.remaining,
    this.error,
  });
}

class AttendanceSyncService {
  final HrmsLocalDataSource local;
  final HrmsRemoteDataSource remote;

  bool _isSyncing = false;

  AttendanceSyncService({required this.local, required this.remote});

  Future<AttendanceSyncResult> syncPendingEvents() async {
    if (_isSyncing) {
      throw StateError('Attendance synchronization is already running.');
    }

    _isSyncing = true;

    var synced = 0;
    var rejected = 0;
    String? errorMessage;

    try {
      // The local data source must return events ordered by created_order.
      final pending = await local.getPendingAttendanceEvents();

      for (final event in pending) {
        try {
          await remote.submitAttendanceEvent(event);

          await local.updateAttendanceStatus(
            event.id,
            AttendanceSyncStatus.synced,
          );
          synced++;
        } on DioException catch (error) {
          final statusCode = error.response?.statusCode;

          if (statusCode == 400 || statusCode == 409 || statusCode == 422) {
            await local.updateAttendanceStatus(
              event.id,
              AttendanceSyncStatus.rejected,
            );
            rejected++;
            continue;
          }

          // Network errors, timeouts and server errors are uncertain.
          // Keep this event Pending and stop here to preserve event order.
          errorMessage = error.message ?? 'The attendance server could not be reached. Pending events were retained.';
          break;
        } catch (_) {
          // Unknown failure: preserve this event and later events as Pending.
          errorMessage =
              'Synchronization failed. Pending events were retained.';
          break;
        }
      }

      final remaining = (await local.getPendingAttendanceEvents()).length;

      return AttendanceSyncResult(
        synced: synced,
        rejected: rejected,
        remaining: remaining,
        error: errorMessage,
      );
    } finally {
      _isSyncing = false;
    }
  }
}
