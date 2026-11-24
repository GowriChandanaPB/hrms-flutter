
import '../models/leave_balance_model.dart';
import '../models/leave_request_model.dart';

abstract class LeaveRepository {
  Future<LeaveBalanceModel> getLeaveBalance();

  Future<List<LeaveRequestModel>> getLeaveRequests();

  Future<void> submitLeaveRequest(LeaveRequestModel request);
}
