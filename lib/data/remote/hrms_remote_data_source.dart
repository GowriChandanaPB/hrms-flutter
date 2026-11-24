
import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/employee_model.dart';
import '../models/attendance_event_model.dart';
import '../models/leave_balance_model.dart';
import '../models/leave_request_model.dart';

class HrmsRemoteDataSource {
  final Dio _dio;

  HrmsRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  Future<EmployeeModel> getEmployee() async {
    final response = await _dio.get(ApiEndpoints.employee);
    final data = Map<String, dynamic>.from(response.data as Map);
    return EmployeeModel.fromJson(data);
  }

  Future<List<AttendanceEventModel>> getAttendance({
    required int year,
    required int month,
  }) async {
    final monthString = '$year-${month.toString().padLeft(2, '0')}';

    final response = await _dio.get(
      ApiEndpoints.attendance,
      queryParameters: {'month': monthString},
    );

    final rows = _asList(response.data);
    return rows
        .map((row) => AttendanceEventModel.fromJson(row))
        .toList();
  }

  Future<AttendanceEventModel> submitAttendanceEvent(
    AttendanceEventModel event,
  ) async {
    final response = await _dio.post(
      ApiEndpoints.attendanceEvents,
      data: event.toJson(),
      options: Options(
        headers: {'Idempotency-Key': event.id},
      ),
    );

    return AttendanceEventModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<LeaveBalanceModel> getLeaveBalance() async {
    final response = await _dio.get(ApiEndpoints.leaveBalance);
    return LeaveBalanceModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<LeaveRequestModel>> getLeaveRequests() async {
    final response = await _dio.get(ApiEndpoints.leaveRequests);
    final rows = _asList(response.data);

    return rows
        .map((row) => LeaveRequestModel.fromJson(row))
        .toList();
  }

  Future<LeaveRequestModel> submitLeaveRequest(
    LeaveRequestModel request,
  ) async {
    final response = await _dio.post(
      ApiEndpoints.leaveRequests,
      data: request.toJson(),
      options: Options(
        headers: {'Idempotency-Key': request.id},
      ),
    );

    return LeaveRequestModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    // Supports either a raw JSON array or { "data": [...] }.
    final value = data is Map ? data['data'] : data;

    if (value is! List) {
      throw const FormatException('Expected a list in the API response.');
    }

    return value
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
