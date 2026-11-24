
import 'package:flutter/widgets.dart';

import '../../../core/services/connectivity_monitor.dart';
import '../../../data/local/hrms_local_data_source.dart';
import '../../../data/models/attendance_event_model.dart';
import 'attendance_sync_service.dart';

/// Owns automatic triggers and the single shared lock used by Sync Center.
class AttendanceSyncCoordinator extends ChangeNotifier
    with WidgetsBindingObserver {
  AttendanceSyncCoordinator({
    required ConnectivityMonitor connectivity,
    required AttendanceSyncService syncService,
    required HrmsLocalDataSource local,
  })  : _connectivity = connectivity,
        _syncService = syncService,
        _local = local;

  final ConnectivityMonitor _connectivity;
  final AttendanceSyncService _syncService;
  final HrmsLocalDataSource _local;

  bool _started = false;
  bool _isSyncing = false;
  bool isAutomaticSync = false;
  bool _wasBackgrounded = false;

  bool isOnline = false;

  int pendingCount = 0;
  int syncedCount = 0;
  int rejectedCount = 0;

  List<AttendanceEventModel> events = const [];

  DateTime? lastSuccessfulSync;
  String? lastError;

  bool get isSyncing => _isSyncing;

  void start() {
    if (_started) return;

    _started = true;

    WidgetsBinding.instance.addObserver(this);

    isOnline = _connectivity.isOnline;
    _connectivity.addListener(_onConnectivityChanged);

    refreshCounts();

    _connectivity.refresh().then((online) {
      if (!_started) return;

      isOnline = online;
      notifyListeners();

      if (online) {
        syncPendingEvents(automatic: true);
      }
    }).catchError((Object error) {
      if (!_started) return;

      lastError = 'Unable to check network connectivity.';
      notifyListeners();
    });
  }

  void _onConnectivityChanged() {
    if (!_started) return;

    final wasOnline = isOnline;
    isOnline = _connectivity.isOnline;

    notifyListeners();

    if (!wasOnline && isOnline) {
      syncPendingEvents(automatic: true);
    }
  }

  Future<void> refreshCounts() async {
    try {
      final attendanceEvents = await _local.getAttendanceEvents();

      events = attendanceEvents;

      pendingCount = attendanceEvents
          .where((e) => e.syncStatus == AttendanceSyncStatus.pending)
          .length;

      syncedCount = attendanceEvents
          .where((e) => e.syncStatus == AttendanceSyncStatus.synced)
          .length;

      rejectedCount = attendanceEvents
          .where((e) => e.syncStatus == AttendanceSyncStatus.rejected)
          .length;

      lastError = null;
    } catch (_) {
      lastError = 'Unable to read local synchronization status.';
    }

    if (_started) {
      notifyListeners();
    }
  }

  Future<AttendanceSyncResult?> syncPendingEvents({
    bool automatic = false,
  }) async {
    if (_isSyncing) return null;

    if (!isOnline) {
      lastError =
          'Device is offline. Pending events are saved on this device.';
      notifyListeners();
      return null;
    }

    _isSyncing = true;
    isAutomaticSync = automatic;
    lastError = null;

    notifyListeners();

    try {
      await refreshCounts();

      if (pendingCount == 0) return null;

      final result = await _syncService.syncPendingEvents();

      if (result.synced > 0) {
        lastSuccessfulSync = DateTime.now();
      }

      await refreshCounts();

      lastError = result.error;

      return result;
    } catch (error) {
      lastError = 'Synchronization could not complete: $error';

      await refreshCounts();

      return null;
    } finally {
      _isSyncing = false;
      isAutomaticSync = false;

      if (_started) {
        notifyListeners();
      }
    }
  }


Future<void> syncPendingEventsIfConnected() async {
  try {
    isOnline = await _connectivity.refresh();

    if (!_started) {
      // Explicit sync requests should work even before lifecycle
      // observation and automatic connectivity triggers are started.
      notifyListeners();
    } else {
      notifyListeners();
    }

    if (isOnline) {
      await syncPendingEvents(automatic: true);
    } else {
      await refreshCounts();
    }
  } catch (error) {
    lastError = 'Unable to refresh connectivity before synchronization.';
    await refreshCounts();
  }
}


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;

      _connectivity.refresh().then((online) {
        if (!_started) return;

        isOnline = online;
        notifyListeners();

        if (online) {
          syncPendingEvents(automatic: true);
        }
      }).catchError((Object error) {
        if (!_started) return;

        lastError = 'Unable to refresh connectivity after resuming.';
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _started = false;

    _connectivity.removeListener(_onConnectivityChanged);
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }
}
