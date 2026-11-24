import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/connectivity_monitor.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/employee_header.dart';
import 'widgets/attendance_card.dart';
import 'widgets/leave_balance_card.dart';
import 'widgets/sync_status_card.dart';
import 'widgets/recent_attendance_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Employee header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: const EmployeeHeader(),
              ),
            ),

            // Date and online status
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _currentDate(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const _ConnectionIndicator(),
                  ],
                ),
              ),
            ),

            // Attendance card
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 20, 18, 0),
                child: AttendanceCard(),
              ),
            ),

            // Overview heading
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 13),
                child: Text(
                  'Your Overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.08, end: 0),
              ),
            ),

            // Overview cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      Expanded(child: LeaveBalanceCard()),
                      SizedBox(width: 12),
                      Expanded(child: SyncStatusCard()),
                    ],
                  ),
                ),
              ),
            ),

            // Recent attendance heading
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                child: const RecentAttendanceCard(),
              ),
            ),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 25)),
          ],
        ),
      ),
    );
  }

  String _currentDate() {
    final now = DateTime.now();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return '${weekdays[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator();

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityMonitor>().isOnline;
    final statusColor = isOnline ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fade(begin: 0.45, end: 1, duration: 1000.ms),

          const SizedBox(width: 6),

          Tooltip(
            message:
                'Network status only; it does not confirm API reachability.',
            child: Text(
              isOnline ? 'Network' : 'Offline',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
