
import '../../core/utils/calendar_date.dart';

enum LeaveType {
  casual,
  sick,
}

enum LeaveRequestStatus {
  pending,
  approved,
  rejected,
}

class LeaveRequestModel {
  final String id;
  final String employeeId;
  final LeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveRequestStatus status;

  const LeaveRequestModel({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = LeaveRequestStatus.pending,
  });

  int get totalDays => inclusiveCalendarDays(startDate, endDate);

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    final leaveType = switch (json['type']) {
      'casual' => LeaveType.casual,
      'sick' => LeaveType.sick,
      _ => throw FormatException(
          'Invalid leave type: ${json['type']}',
        ),
    };

    final requestStatus = switch (json['status']) {
      null => LeaveRequestStatus.pending,
      'pending' => LeaveRequestStatus.pending,
      'approved' => LeaveRequestStatus.approved,
      'rejected' => LeaveRequestStatus.rejected,
      _ => throw FormatException(
          'Invalid leave request status: ${json['status']}',
        ),
    };

    return LeaveRequestModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      type: leaveType,
      startDate: parseCalendarDate(json['startDate']),
      endDate: parseCalendarDate(json['endDate']),
      reason: json['reason']?.toString() ?? '',
      status: requestStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'type': type.name,
        'startDate': calendarDateString(startDate),
        'endDate': calendarDateString(endDate),
        'reason': reason,
        'status': status.name,
      };
}
