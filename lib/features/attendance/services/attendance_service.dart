import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/company_time.dart';
import '../../../data/local/hrms_local_data_source.dart';
import '../../../data/models/attendance_event_model.dart';
import 'location_service.dart';

class AttendanceService {
  AttendanceService({
    required HrmsLocalDataSource localDataSource,
    required LocationService locationService,
    DateTime Function()? clock,
  }) : _local = localDataSource,
       _location = locationService,
       _clock = clock ?? DateTime.now;

  final HrmsLocalDataSource _local;
  final LocationService _location;
  final DateTime Function() _clock;

  final Uuid _uuid = const Uuid();
  bool _isProcessing = false;

  Future<AttendanceEventModel> checkIn() {
    return _recordEvent(AttendanceEventType.checkIn);
  }

  Future<AttendanceEventModel> checkOut() {
    return _recordEvent(AttendanceEventType.checkOut);
  }

  Future<AttendanceEventModel> _recordEvent(AttendanceEventType type) async {
    if (_isProcessing) {
      throw const AttendanceException(
        'An attendance action is already in progress.',
      );
    }

    _isProcessing = true;

    try {
      final now = _clock();
      final events = await _local.getAttendanceEvents();

      final todayEvents = events.where((event) {
        return event.employeeId == AppConfig.employeeId &&
            isSameCompanyDay(event.timestamp, now);
      }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final validCheckIns = todayEvents.where((event) {
        return event.type == AttendanceEventType.checkIn &&
            event.syncStatus != AttendanceSyncStatus.rejected &&
            !event.timestamp.isAfter(now);
      }).toList();

      final hasValidCheckOut = todayEvents.any((event) {
        return event.type == AttendanceEventType.checkOut &&
            event.syncStatus != AttendanceSyncStatus.rejected &&
            !event.timestamp.isAfter(now) &&
            validCheckIns.any(
              (checkIn) => !event.timestamp.isBefore(checkIn.timestamp),
            );
      });

      if (type == AttendanceEventType.checkIn && validCheckIns.isNotEmpty) {
        throw const AttendanceException('You have already checked in today.');
      }

      if (type == AttendanceEventType.checkOut && validCheckIns.isEmpty) {
        throw const AttendanceException(
          'You must check in before checking out.',
        );
      }

      if (type == AttendanceEventType.checkOut && hasValidCheckOut) {
        throw const AttendanceException('You have already checked out today.');
      }

      final location = await _location.verifyOfficeLocation();

      if (!location.isAccurate) {
        throw AttendanceException(
          'GPS accuracy is ${location.accuracyInMetres.toStringAsFixed(0)} '
          'metres. A fix within '
          '${AppConfig.maximumLocationAccuracyMetres.toStringAsFixed(0)} '
          'metres is required before recording attendance.',
        );
      }

      if (!location.isWithinOfficeRange) {
        throw AttendanceException(
          'You are ${location.distanceInMetres.toStringAsFixed(0)} metres '
          'from the office. You must be within '
          '${AppConfig.allowedOfficeRadiusMetres.toStringAsFixed(0)} metres '
          'to record attendance. GPS: ${location.latitude}, '
          '${location.longitude}; office: ${AppConfig.officeLatitude}, '
          '${AppConfig.officeLongitude}.',
        );
      }

      final event = AttendanceEventModel(
        id: _uuid.v4(),
        employeeId: AppConfig.employeeId,
        type: type,
        timestamp: now,
        latitude: location.latitude,
        longitude: location.longitude,
        syncStatus: AttendanceSyncStatus.pending,
      );

      await _local.saveAttendanceEvent(event);

      return event;
    } finally {
      _isProcessing = false;
    }
  }
}

class AttendanceException implements Exception {
  final String message;

  const AttendanceException(this.message);

  @override
  String toString() => message;
}
