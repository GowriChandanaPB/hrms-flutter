import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import 'services/attendance_service.dart';
import 'services/location_service.dart';
import 'services/attendance_state.dart';
import '../sync/services/attendance_sync_coordinator.dart';

enum AttendanceAction { checkIn, checkOut }

class AttendanceVerificationScreen extends StatefulWidget {
  const AttendanceVerificationScreen({super.key, required this.action});
  final AttendanceAction action;

  @override
  State<AttendanceVerificationScreen> createState() =>
      _AttendanceVerificationScreenState();
}

class _AttendanceVerificationScreenState
    extends State<AttendanceVerificationScreen> {
  bool _isConfirming = false;
  bool _isReadingLocation = false;
  LocationVerificationResult? _locationDiagnostic;
  String? _locationDiagnosticError;

  Future<void> _readLocationDiagnostic() async {
    if (_isReadingLocation) return;

    setState(() {
      _isReadingLocation = true;
      _locationDiagnostic = null;
      _locationDiagnosticError = null;
    });

    try {
      final result = await context
          .read<LocationService>()
          .verifyOfficeLocation();
      if (!mounted) return;
      setState(() => _locationDiagnostic = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationDiagnosticError = error.toString());
    } finally {
      if (mounted) setState(() => _isReadingLocation = false);
    }
  }

  Future<void> _confirmAttendance() async {
    if (_isConfirming) return;

    setState(() => _isConfirming = true);

    try {
      final service = context.read<AttendanceService>();
      final attendanceState = context.read<AttendanceState>();
      final syncCoordinator = context.read<AttendanceSyncCoordinator>();
      if (widget.action == AttendanceAction.checkIn) {
        await service.checkIn();
      } else {
        await service.checkOut();
      }
      await attendanceState.refresh(fetchRemote: false);
      await syncCoordinator.refreshCounts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.action == AttendanceAction.checkIn
                ? 'Check-in recorded successfully!'
                : 'Check-out recorded successfully!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
      unawaited(
        syncCoordinator.syncPendingEventsIfConnected().then(
          (_) => attendanceState.refresh(fetchRemote: false),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.cardTheme.color ?? colors.surface;
    final secondaryText = colors.onSurface.withValues(alpha: 0.60);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, secondaryText),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildHeading(colors, secondaryText),
                    const SizedBox(height: 28),
                    _buildLocationIllustration(isDark, colors),
                    const SizedBox(height: 26),
                    _buildInfoCard(colors),
                    const SizedBox(height: 24),
                    _buildOfficeDetails(surface, colors, secondaryText),
                    const SizedBox(height: 16),
                    _buildLocationDiagnostics(colors, secondaryText),
                    const SizedBox(height: 28),
                    _buildConfirmButton(),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Your location is only used to verify attendance.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryText,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color secondaryText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Attendance Verification',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Icon(Icons.verified_user_outlined, color: secondaryText, size: 21),
        ],
      ),
    );
  }

  Widget _buildHeading(ColorScheme colors, Color secondaryText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.action == AttendanceAction.checkIn ? 'Check In' : 'Check Out',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Your location will be verified before recording attendance.',
          style: TextStyle(fontSize: 14, height: 1.5, color: secondaryText),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.12);
  }

  Widget _buildLocationIllustration(bool isDark, ColorScheme colors) {
    return Center(
      child: SizedBox(
        height: 235,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.045),
              ),
            ),
            Container(
                  width: 174,
                  height: 174,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.13),
                      width: 1.5,
                    ),
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .scale(
                  begin: const Offset(0.94, 0.94),
                  end: const Offset(1.06, 1.06),
                  duration: 2200.ms,
                  curve: Curves.easeInOut,
                ),
            Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 45,
                  ),
                )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(
                  begin: const Offset(0.65, 0.65),
                  duration: 650.ms,
                  curve: Curves.easeOutBack,
                ),
            Positioned(top: 24, right: 55, child: _buildFloatingDot()),
            Positioned(bottom: 30, left: 55, child: _buildFloatingDot()),
            Positioned(
              bottom: 42,
              right: 64,
              child: Icon(
                Icons.my_location_rounded,
                color: AppColors.primary.withValues(alpha: 0.65),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 3,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms);
  }

  Widget _buildInfoCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_searching_rounded,
              color: AppColors.primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Verification',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your current GPS location will be checked against the office radius of ${AppConfig.allowedOfficeRadiusMetres.toStringAsFixed(0)} metres.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08);
  }

  Widget _buildOfficeDetails(
    Color surface,
    ColorScheme colors,
    Color secondaryText,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.business_rounded,
                color: AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 9),
              const Text(
                'Office Location',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              const Text(
                'Configured',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'Teqbae innovations and solutions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Kochi, Kerala, India',
            style: TextStyle(fontSize: 12, color: secondaryText),
          ),
          const SizedBox(height: 14),
          Divider(color: colors.outline.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 13),
          Row(
            children: [
              Icon(Icons.explore_outlined, color: secondaryText, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AppConfig.officeLatitude.toStringAsFixed(6)}° N, '
                  '${AppConfig.officeLongitude.toStringAsFixed(6)}° E',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Icon(Icons.location_on_outlined, color: secondaryText, size: 17),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 340.ms).slideY(begin: 0.08);
  }

  Widget _buildLocationDiagnostics(ColorScheme colors, Color secondaryText) {
    final result = _locationDiagnostic;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location diagnostics',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reads the coordinates currently supplied by the device.',
            style: TextStyle(fontSize: 12, color: secondaryText),
          ),
          const SizedBox(height: 12),
          _diagnosticRow(
            'Office',
            '${AppConfig.officeLatitude}, ${AppConfig.officeLongitude}',
            colors,
          ),
          _diagnosticRow(
            'Allowed radius',
            '${AppConfig.allowedOfficeRadiusMetres.toStringAsFixed(0)} m',
            colors,
          ),
          _diagnosticRow('Timezone', AppConfig.timezone, colors),
          if (result != null) ...[
            _diagnosticRow(
              'Current GPS',
              '${result.latitude}, ${result.longitude}',
              colors,
            ),
            _diagnosticRow(
              'GPS accuracy',
              '${result.accuracyInMetres.toStringAsFixed(1)} m'
                  '${result.isAccurate ? '' : ' (too inaccurate)'}',
              colors,
            ),
            _diagnosticRow(
              'Distance',
              '${result.distanceInMetres.toStringAsFixed(1)} m'
                  '${result.isWithinOfficeRange ? ' (inside radius)' : ' (outside radius)'}',
              colors,
            ),
          ],
          if (_locationDiagnosticError != null) ...[
            const SizedBox(height: 6),
            Text(
              _locationDiagnosticError!,
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isReadingLocation ? null : _readLocationDiagnostic,
            icon: _isReadingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined, size: 18),
            label: Text(
              _isReadingLocation ? 'Reading GPS...' : 'Read current GPS fix',
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticRow(String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
          width: double.infinity,
          height: 57,
          child: ElevatedButton(
            onPressed: _isConfirming ? null : _confirmAttendance,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(
                alpha: 0.55,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isConfirming
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      key: ValueKey('confirm'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint_rounded, size: 22),
                        SizedBox(width: 10),
                        Text(
                          widget.action == AttendanceAction.checkIn
                              ? 'Confirm Check In'
                              : 'Confirm Check Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 420.ms)
        .scale(begin: const Offset(0.96, 0.96), duration: 400.ms);
  }
}
