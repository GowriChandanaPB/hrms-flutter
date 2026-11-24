import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'dart:async';

import 'package:provider/provider.dart';

import '../../attendance/attendance_verification_screen.dart';
import '../../attendance/services/attendance_state.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/company_time.dart';
import '../../../widgets/animated_button.dart';
import '../../../widgets/status_badge.dart';

class AttendanceCard extends StatefulWidget {
  const AttendanceCard({super.key});

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  Timer? _timer;
  bool _busy = false;
  DateTime _clock = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _clock = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AttendanceState>().refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';

    final companyTime = companyWallTime(time);

    final hour = companyTime.hour % 12 == 0 ? 12 : companyTime.hour % 12;
    final minute = companyTime.minute.toString().padLeft(2, '0');
    final period = companyTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _duration(DateTime? checkIn, DateTime? checkOut) {
    if (checkIn == null) return '00h 00m';
    final difference = (checkOut ?? _clock).difference(checkIn);

    final hours = difference.inHours.toString().padLeft(2, '0');
    final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');

    return '${hours}h ${minutes}m';
  }

  Future<void> _handleAttendance(bool checkedIn) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceVerificationScreen(
          action: checkedIn
              ? AttendanceAction.checkOut
              : AttendanceAction.checkIn,
        ),
      ),
    );
    if (!mounted) return;
    await context.read<AttendanceState>().refresh(fetchRemote: false);
    setState(() => _busy = false);
    if (result == true) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final attendance = context.watch<AttendanceState>();
    final checkIn = attendance.todayCheckIn?.timestamp;
    final checkOut = attendance.todayCheckOut?.timestamp;
    final checkedIn = checkIn != null;
    final checkedOut = checkOut != null;

    final status = !checkedIn
        ? StatusType.warning
        : checkedOut
        ? StatusType.info
        : StatusType.success;

    final statusLabel = !checkedIn
        ? 'Not Checked In'
        : checkedOut
        ? 'Checked Out'
        : 'Checked In';

    return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: isDark
                ? AppColors.darkCardGradient
                : AppColors.lightCardGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.10 : 0.10,
                ),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Today's Attendance",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: StatusBadge(
                      key: ValueKey(statusLabel),
                      label: statusLabel,
                      status: status,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: _TimeInfo(
                      label: 'Check In',
                      time: _formatTime(checkIn),
                      icon: Icons.login_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 42,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _TimeInfo(
                      label: 'Check Out',
                      time: _formatTime(checkOut),
                      icon: Icons.logout_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),

              const SizedBox(height: 13),

              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 19,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 9),
                  Text('Working Duration', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _duration(checkIn, checkOut),
                      key: ValueKey(_duration(checkIn, checkOut)),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: checkedOut
                    ? Container(
                        key: const ValueKey('completed'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Attendance Completed',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      )
                    : AnimatedButton(
                        key: ValueKey(checkedIn),
                        label: _busy
                            ? 'Please wait…'
                            : checkedIn
                            ? 'Check Out'
                            : 'Check In',
                        icon: checkedIn
                            ? Icons.logout_rounded
                            : Icons.login_rounded,
                        foregroundColor: checkedIn && !isDark
                            ? Colors.black
                            : Colors.white,
                        backgroundColor: checkedIn && !isDark
                            ? const Color(0xFFC9BDFB)
                            : null,
                        onPressed: _busy || attendance.isLoading
                            ? null
                            : () => _handleAttendance(checkedIn),
                      ),
              ),

              const SizedBox(height: 10),

              Text(
                attendance.error ??
                    'Attendance is recorded after GPS verification.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 650.ms, delay: 150.ms)
        .slideY(
          begin: 0.12,
          end: 0,
          duration: 650.ms,
          delay: 150.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _TimeInfo extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final Color color;

  const _TimeInfo({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  time,
                  key: ValueKey(time),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
