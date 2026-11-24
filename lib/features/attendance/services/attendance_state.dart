
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/company_time.dart';
import '../../../data/local/hrms_local_data_source.dart';
import '../../../data/models/attendance_event_model.dart';
import '../../../data/remote/hrms_remote_data_source.dart';

/// Shared, SQLite-backed attendance snapshot used by the dashboard and history.
///
/// The clock is injectable so tests can simulate different company dates.
/// Production uses the actual device time by default.
class AttendanceState extends ChangeNotifier {
  AttendanceState(
    this._local,
    this._remote, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final HrmsLocalDataSource _local;
  final HrmsRemoteDataSource _remote;

  final DateTime Function() _clock;

  List<AttendanceEventModel> events = const [];
  bool isLoading = false;
  String? error;

  Future<void> refresh({
    int? year,
    int? month,
    bool fetchRemote = true,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      if (fetchRemote) {
        final requestedMonth = companyCalendarDate(_clock());

        final months = year != null && month != null
            ? [DateTime(year, month)]
            : [
                DateTime(requestedMonth.year, requestedMonth.month),
                DateTime(requestedMonth.year, requestedMonth.month - 1),
              ];

        for (final targetMonth in months) {
          try {
            final remoteEvents = await _remote.getAttendance(
              year: targetMonth.year,
              month: targetMonth.month,
            );

            for (final event in remoteEvents) {
              await _local.saveAttendanceEvent(event);
            }
          } catch (_) {
            // Continue with the local cache when offline or when the API fails.
          }
        }
      }

      // Keep a complete local snapshot while screens select different months.
      final rows = await _local.getAttendanceEvents();

      events = rows
          .where((e) => e.employeeId == AppConfig.employeeId)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (_) {
      error = 'Unable to load attendance from this device.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<AttendanceEventModel> eventsOn(DateTime date) {
    final selectedDate = DateTime(date.year, date.month, date.day);

    return events
        .where((e) => companyCalendarDate(e.timestamp) == selectedDate)
        .toList();
  }

  List<AttendanceEventModel> get todayEvents =>
      eventsOn(companyCalendarDate(_clock()));

  AttendanceEventModel? get todayCheckIn =>
      _first(AttendanceEventType.checkIn);

  AttendanceEventModel? get todayCheckOut =>
      _first(AttendanceEventType.checkOut);

  AttendanceEventModel? _first(AttendanceEventType type) {
    for (final event in todayEvents) {
      if (event.type == type &&
          event.syncStatus != AttendanceSyncStatus.rejected) {
        return event;
      }
    }

    return null;
  }
}
