import '../../../core/config/app_config.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/company_time.dart';
import '../../../data/models/leave_request_model.dart';

enum LeaveValidationField {
  leaveType,
  startDate,
  endDate,
  reason,
  balance,
  overlap,
  connectivity,
}

class LeaveValidation {
  LeaveValidation._();

  static DateTime companyToday(DateTime now) {
    return calendarDate(companyCalendarDate(now));
  }

  static String? startDateError(DateTime startDate, DateTime today) {
    if (calendarDate(startDate).isBefore(calendarDate(today))) {
      return 'Start date cannot be before today (${AppConfig.timezone}).';
    }
    return null;
  }

  static String? endDateError(DateTime startDate, DateTime endDate) {
    if (calendarDate(endDate).isBefore(calendarDate(startDate))) {
      return 'End date cannot be before the start date.';
    }
    return null;
  }

  static String normalizeReason(String reason) => reason.trim();

  static String? reasonError(String reason) {
    if (normalizeReason(reason).replaceAll(RegExp(r'\s+'), '').length < 10) {
      return 'Enter at least 10 non-whitespace characters.';
    }
    return null;
  }

  static int requestedDays(DateTime startDate, DateTime endDate) =>
      inclusiveCalendarDays(startDate, endDate);

  static bool overlapsActiveRequest({
    required DateTime startDate,
    required DateTime endDate,
    required Iterable<LeaveRequestModel> requests,
    required String employeeId,
  }) {
    final start = calendarDate(startDate);
    final end = calendarDate(endDate);

    return requests.any((request) {
      final active =
          request.status == LeaveRequestStatus.pending ||
          request.status == LeaveRequestStatus.approved;
      if (!active || request.employeeId != employeeId) return false;

      return !calendarDate(request.startDate).isAfter(end) &&
          !calendarDate(request.endDate).isBefore(start);
    });
  }
}
