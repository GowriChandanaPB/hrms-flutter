
import '../local/hrms_local_data_source.dart';
import '../models/leave_balance_model.dart';
import '../models/leave_request_model.dart';
import '../remote/hrms_remote_data_source.dart';
import 'leave_repository.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  final HrmsRemoteDataSource remote;
  final HrmsLocalDataSource local;

  LeaveRepositoryImpl({
    required this.remote,
    required this.local,
  });

  @override
  Future<LeaveBalanceModel> getLeaveBalance() async {
    try {
      final balance = await remote.getLeaveBalance();
      await local.saveLeaveBalance(balance);
      return balance;
    } catch (_) {
      final cached = await local.getLeaveBalance();
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests() async {
    try {
      final requests = await remote.getLeaveRequests();

      for (final request in requests) {
        await local.saveLeaveRequest(request);
      }

      return requests;
    } catch (_) {
      return local.getLeaveRequests();
    }
  }

  @override
  Future<LeaveRequestModel> submitLeaveRequest(
    LeaveRequestModel request,
  ) async {
    // Submit remotely first. Do not save a leave request as Pending
    // locally if the server has rejected it or the device is offline.
    final saved = await remote.submitLeaveRequest(request);
    await local.saveLeaveRequest(saved);
    return saved;
  }
}
