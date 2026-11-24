import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/company_time.dart';
import '../../../data/models/attendance_event_model.dart';
import '../../../features/attendance/attendance_screen.dart';
import '../../../features/attendance/services/attendance_state.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/status_badge.dart';

class RecentAttendanceCard extends StatelessWidget {
  const RecentAttendanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attendance = context.watch<AttendanceState>();
    final records = _groupEvents(attendance.events);
    final visibleRecords = records.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Attendance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const AttendanceScreen(showBackButton: true),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 9),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: attendance.isLoading && records.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : records.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text(
                      attendance.error ?? 'No attendance records yet.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < visibleRecords.length;
                      index++
                    ) ...[
                      _AttendanceRecordTile(record: visibleRecords[index])
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 100 + index * 100),
                            duration: 400.ms,
                          )
                          .slideX(
                            begin: 0.06,
                            end: 0,
                            delay: Duration(milliseconds: 100 + index * 100),
                            duration: 450.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      if (index != visibleRecords.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  List<_AttendanceRecord> _groupEvents(List<AttendanceEventModel> events) {
    final grouped = <String, List<AttendanceEventModel>>{};
    for (final event in events) {
      final date = companyCalendarDate(event.timestamp);
      final key = '${date.year}-${date.month}-${date.day}';
      grouped.putIfAbsent(key, () => []).add(event);
    }

    final records =
        grouped.values.map((items) {
            items.sort(
              (first, second) => first.timestamp.compareTo(second.timestamp),
            );
            final checkIn = items
                .where((event) => event.type == AttendanceEventType.checkIn)
                .firstOrNull
                ?.timestamp;
            final checkOut = items
                .where((event) => event.type == AttendanceEventType.checkOut)
                .lastOrNull
                ?.timestamp;
            final status =
                items.any(
                  (event) => event.syncStatus == AttendanceSyncStatus.rejected,
                )
                ? StatusType.error
                : items.any(
                    (event) => event.syncStatus == AttendanceSyncStatus.pending,
                  )
                ? StatusType.pending
                : StatusType.success;
            final latest = items.last.timestamp;
            final companyLatest = companyCalendarDate(latest);

            return _AttendanceRecord(
              dateTime: companyLatest,
              date: _formatDate(companyLatest),
              checkIn: _formatTime(checkIn),
              checkOut: _formatTime(checkOut),
              status: status,
            );
          }).toList()
          ..sort((first, second) => second.dateTime.compareTo(first.dateTime));

    return records;
  }

  String _formatDate(DateTime date) {
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
    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '--:--';
    final companyTime = companyWallTime(date);
    final hour = companyTime.hour % 12 == 0 ? 12 : companyTime.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:'
        '${companyTime.minute.toString().padLeft(2, '0')} '
        '${companyTime.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _AttendanceRecord {
  final DateTime dateTime;
  final String date;
  final String checkIn;
  final String checkOut;
  final StatusType status;

  const _AttendanceRecord({
    required this.dateTime,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.status,
  });
}

class _AttendanceRecordTile extends StatelessWidget {
  final _AttendanceRecord record;

  const _AttendanceRecordTile({required this.record});

  String get _statusLabel {
    switch (record.status) {
      case StatusType.pending:
        return 'Pending';
      case StatusType.error:
        return 'Rejected';
      default:
        return 'Synced';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 19,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.date,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${record.checkIn}  •  ${record.checkOut}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          StatusBadge(
            label: _statusLabel,
            status: record.status,
            animate: false,
          ),
        ],
      ),
    );
  }
}
