
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionGranted;

  const LocationPermissionScreen({
    super.key,
    required this.onPermissionGranted,
  });

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends State<LocationPermissionScreen> {
  bool _isLoading = false;
  String? _error;
  bool _showSettingsButton = false;

  Future<void> _enableLocation() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _showSettingsButton = false;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!mounted) return;

      if (!serviceEnabled) {
        setState(() {
          _error =
              'Location Services are turned off. Please enable them in your device settings.';
          _showSettingsButton = true;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!mounted) return;

      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          widget.onPermissionGranted();
          return;

        case LocationPermission.denied:
          setState(() {
            _error =
                'Location permission is required to record your attendance.';
          });
          return;

        case LocationPermission.deniedForever:
          setState(() {
            _error =
                'Location permission has been permanently denied. Enable it in Settings to continue.';
            _showSettingsButton = true;
          });
          return;

        case LocationPermission.unableToDetermine:
          setState(() {
            _error =
                'Unable to determine location permission. Please try again.';
          });
          return;
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Unable to access your location. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 112,
                  width: 112,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 58,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Enable Location Access',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  'REBS HRMS uses your location to verify that '
                  'you are within the permitted office radius '
                  'when recording attendance.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your location is used only for attendance '
                          'verification. It helps confirm that you '
                          'are within 200 metres of the office.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ? null : _enableLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Enable Location',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                if (_showSettingsButton) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _openSettings,
                    child: const Text('Open Settings'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
