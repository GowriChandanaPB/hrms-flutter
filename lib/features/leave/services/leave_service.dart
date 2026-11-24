import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../data/local/hrms_local_data_source.dart';
import '../../../data/models/leave_balance_model.dart';
import '../../../data/models/leave_request_model.dart';
import '../../../data/remote/hrms_remote_data_source.dart';
import 'leave_validation.dart';

class LeaveService {
  LeaveService({
    required this.localDataSource,
    required this.remoteDataSource,
    required Future<bool> Function() isOnline,
    DateTime Function()? clock,
  }) : _isOnline = isOnline,
       _clock = clock ?? DateTime.now;

  final HrmsLocalDataSource localDataSource;
  final HrmsRemoteDataSource remoteDataSource;
  final Future<bool> Function() _isOnline;
  final DateTime Function() _clock;

  static const Uuid _uuid = Uuid();
  bool _isSubmitting = false;

  Future<LeaveBalanceModel> getLeaveBalance() async {
    try {
      final balance = await remoteDataSource.getLeaveBalance();
      await localDataSource.saveLeaveBalance(balance);
      return balance;
    } catch (_) {
      final cached = await localDataSource.getLeaveBalance();
      if (cached != null) return cached;
      throw const LeaveException(
        'Leave balance is unavailable. Connect to the internet and refresh.',
      );
    }
  }

  Future<List<LeaveRequestModel>> getLeaveRequests() async {
    List<LeaveRequestModel> remoteRequests = const [];

    try {
      remoteRequests = await remoteDataSource.getLeaveRequests();
      for (final request in remoteRequests) {
        await localDataSource.saveLeaveRequest(request);
      }
    } catch (_) {
      // The local cache remains available while offline or when the API fails.
    }

    final localRequests = await localDataSource.getLeaveRequests();
    final requestsById = <String, LeaveRequestModel>{
      for (final request in localRequests) request.id: request,
    };
    for (final request in remoteRequests) {
      requestsById[request.id] = request;
    }

    final requests = requestsById.values.toList()
      ..sort((first, second) => second.startDate.compareTo(first.startDate));
    return requests;
  }

  Future<LeaveRequestModel> submitLeaveRequest({
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    if (_isSubmitting) {
      throw const LeaveException(
        'A leave request is already being submitted.',
      );
    }

    _isSubmitting = true;
    try {
      if (!await _isOnline()) {
        throw const LeaveException(
          'You are offline. Connect to the internet before submitting a leave request.',
          field: LeaveValidationField.connectivity,
        );
      }

      final start = calendarDate(startDate);
      final end = calendarDate(endDate);
      final today = LeaveValidation.companyToday(_clock());

      final startError = LeaveValidation.startDateError(start, today);
      if (startError != null) {
        throw LeaveException(startError, field: LeaveValidationField.startDate);
      }

      final endError = LeaveValidation.endDateError(start, end);
      if (endError != null) {
        throw LeaveException(endError, field: LeaveValidationField.endDate);
      }

      final normalizedReason = LeaveValidation.normalizeReason(reason);
      final reasonError = LeaveValidation.reasonError(normalizedReason);
      if (reasonError != null) {
        throw LeaveException(reasonError, field: LeaveValidationField.reason);
      }

      final requestedDays = LeaveValidation.requestedDays(start, end);
      final balance = await getLeaveBalance();
      final availableDays = type == LeaveType.casual
          ? balance.casualLeave
          : balance.sickLeave;

      if (requestedDays > availableDays) {
        throw LeaveException(
          'Requested $requestedDays days exceeds the ${_leaveTypeName(type)} '
          'balance of $availableDays days.',
          field: LeaveValidationField.balance,
        );
      }

      final requests = await getLeaveRequests();
      if (LeaveValidation.overlapsActiveRequest(
        startDate: start,
        endDate: end,
        requests: requests,
        employeeId: AppConfig.employeeId,
      )) {
        throw const LeaveException(
          'These dates overlap a pending or approved leave request.',
          field: LeaveValidationField.overlap,
        );
      }

      final request = LeaveRequestModel(
        id: _uuid.v4(),
        employeeId: AppConfig.employeeId,
        type: type,
        startDate: start,
        endDate: end,
        reason: normalizedReason,
      );

      final savedRequest = await remoteDataSource.submitLeaveRequest(request);
      await localDataSource.saveLeaveRequest(savedRequest);

      try {
        await getLeaveBalance();
      } catch (_) {
        // The accepted request remains successful even if the balance refresh fails.
      }

      return savedRequest;
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      throw LeaveException(
        message ?? 'Unable to submit the leave request. Please try again.',
      );
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required LeaveRequestStatus status,
  }) {
    return localDataSource.updateLeaveRequestStatus(requestId, status);
  }

  String _leaveTypeName(LeaveType type) =>
      type == LeaveType.casual ? 'Casual Leave' : 'Sick Leave';
}

class LeaveException implements Exception {
  final String message;
  final LeaveValidationField? field;

  const LeaveException(this.message, {this.field});

  @override
  String toString() => message;
}