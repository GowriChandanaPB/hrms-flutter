import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'core/services/connectivity_monitor.dart';
import 'data/local/hrms_local_data_source.dart';
import 'data/repositories/employee_repository.dart';
import 'data/repositories/employee_repository_impl.dart';
import 'data/remote/hrms_remote_data_source.dart';
import 'features/attendance/services/attendance_service.dart';
import 'features/attendance/services/attendance_state.dart';
import 'features/attendance/services/location_service.dart';
import 'features/leave/services/leave_service.dart';
import 'features/sync/services/attendance_sync_service.dart';
import 'features/sync/services/attendance_sync_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _requestLocationPermission();

  final localDataSource = HrmsLocalDataSource();
  final DateTime Function() clock = DateTime.now;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        Provider<HrmsLocalDataSource>.value(value: localDataSource),
        Provider<HrmsRemoteDataSource>(create: (_) => HrmsRemoteDataSource()),
        ProxyProvider2<
          HrmsRemoteDataSource,
          HrmsLocalDataSource,
          EmployeeRepository
        >(
          update: (_, remote, local, previous) =>
              previous ?? EmployeeRepositoryImpl(remote: remote, local: local),
        ),
        ChangeNotifierProvider(
          create: (context) => AttendanceState(
            localDataSource,
            context.read<HrmsRemoteDataSource>(),
            clock: clock,
          )..refresh(),
        ),
        ChangeNotifierProvider(create: (_) => ConnectivityMonitor()),
        Provider<LocationService>(create: (_) => LocationService()),
        ProxyProvider2<HrmsLocalDataSource, LocationService, AttendanceService>(
          update: (_, local, location, previous) =>
              previous ??
              AttendanceService(
                localDataSource: local,
                locationService: location,
                clock: clock,
              ),
        ),
        ProxyProvider3<
          HrmsLocalDataSource,
          HrmsRemoteDataSource,
          ConnectivityMonitor,
          LeaveService
        >(
          update: (_, local, remote, connectivity, previous) =>
              previous ??
              LeaveService(
                localDataSource: local,
                remoteDataSource: remote,
                isOnline: connectivity.refresh,
              ),
        ),
        ProxyProvider2<
          HrmsLocalDataSource,
          HrmsRemoteDataSource,
          AttendanceSyncService
        >(
          update: (_, local, remote, previous) =>
              previous ?? AttendanceSyncService(local: local, remote: remote),
        ),
        ChangeNotifierProvider<AttendanceSyncCoordinator>(
          create: (context) => AttendanceSyncCoordinator(
            connectivity: context.read<ConnectivityMonitor>(),
            syncService: context.read<AttendanceSyncService>(),
            local: context.read<HrmsLocalDataSource>(),
          )..start(),
        ),
      ],
      child: const RebsHrmsApp(),
    ),
  );
}

Future<void> _requestLocationPermission() async {
  try {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied.');
    } else if (permission == LocationPermission.denied) {
      debugPrint('Location permission denied.');
    }
  } catch (error) {
    debugPrint('Location permission error: $error');
  }
}
