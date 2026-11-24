import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Reports network interface availability; it does not imply API reachability.
class ConnectivityMonitor extends ChangeNotifier {
  ConnectivityMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    initialize();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool isOnline = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _update(await _connectivity.checkConnectivity());
      _subscription = _connectivity.onConnectivityChanged.listen(_update);
    } catch (_) {
      _update(const [ConnectivityResult.none]);
    }
  }

  Future<bool> refresh() async {
    try {
      _update(await _connectivity.checkConnectivity());
    } catch (_) {
      _update(const [ConnectivityResult.none]);
    }
    return isOnline;
  }

  void _update(List<ConnectivityResult> results) {
    final online = results.any((result) => result != ConnectivityResult.none);
    if (online == isOnline) return;
    isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
