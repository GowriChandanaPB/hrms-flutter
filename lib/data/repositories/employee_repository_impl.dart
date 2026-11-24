
import '../local/hrms_local_data_source.dart';
import '../models/employee_model.dart';
import '../remote/hrms_remote_data_source.dart';
import 'employee_repository.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final HrmsRemoteDataSource remote;
  final HrmsLocalDataSource local;

  EmployeeRepositoryImpl({
    required this.remote,
    required this.local,
  });

  @override
  Future<EmployeeModel> getEmployee() async {
    try {
      final employee = await remote.getEmployee();
      await local.saveEmployee(employee);
      return employee;
    } catch (_) {
      final cached = await local.getEmployee();
      if (cached != null) return cached;
      rethrow;
    }
  }
}
