import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/models/attendance_event_model.dart';
import 'services/attendance_state.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/company_time.dart';
import 'attendance_verification_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.showBackButton = false});

  final bool? showBackButton;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _displayedMonth = companyCalendarDate(DateTime.now());
  DateTime _selectedDate = companyCalendarDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonth());
  }

  Future<void> _loadMonth() => context.read<AttendanceState>().refresh(
    year: _displayedMonth.year,
    month: _displayedMonth.month,
  );

  Map<String, _AttendanceRecord> _records(List<AttendanceEventModel> events) {
    final grouped = <String, List<AttendanceEventModel>>{};
    for (final e in events) {
      grouped
          .putIfAbsent(_dateKey(companyCalendarDate(e.timestamp)), () => [])
          .add(e);
    }
    return grouped.map((key, items) {
      items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final inEvent = items
          .where((e) => e.type == AttendanceEventType.checkIn)
          .firstOrNull;
      final outEvent = items
          .where((e) => e.type == AttendanceEventType.checkOut)
          .firstOrNull;
      final status =
          items.any((e) => e.syncStatus == AttendanceSyncStatus.rejected)
          ? _RecordStatus.rejected
          : items.any((e) => e.syncStatus == AttendanceSyncStatus.pending)
          ? _RecordStatus.pending
          : _RecordStatus.synced;
      final duration = inEvent == null
          ? '--'
          : _duration(inEvent.timestamp, outEvent?.timestamp);
      return MapEntry(
        key,
        _AttendanceRecord(
          checkIn: _format(inEvent?.timestamp),
          checkOut: _format(outEvent?.timestamp),
          duration: duration,
          status: status,
        ),
      );
    });
  }

  String _format(DateTime? date) =>
      date == null ? '--:--' : _formatCompanyTime(date);

  String _formatCompanyTime(DateTime instant) {
    final date = companyWallTime(instant);
    return '${(date.hour % 12 == 0 ? 12 : date.hour % 12).toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _duration(DateTime start, DateTime? end) {
    final d = (end ?? DateTime.now()).difference(start);
    return end == null
        ? 'In progress'
        : '${d.inHours.toString().padLeft(2, '0')}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  _AttendanceRecord? _selectedRecord(Map<String, _AttendanceRecord> records) =>
      records[_dateKey(_selectedDate)];

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + offset,
      );

      _selectedDate = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    });
    _loadMonth();
  }

  String get _monthTitle {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[_displayedMonth.month - 1]} ${_displayedMonth.year}';
  }

  String _selectedDateTitle() {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

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

    return '${weekdays[_selectedDate.weekday - 1]}, '
        '${_selectedDate.day} ${months[_selectedDate.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = context.watch<AttendanceState>();
    final records = _records(state.events);
    final todayIn = state.todayCheckIn != null;
    final todayOut = state.todayCheckOut != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: _buildHeader(theme, widget.showBackButton ?? false),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: todayOut
                        ? null
                        : () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AttendanceVerificationScreen(
                                  action: todayIn
                                      ? AttendanceAction.checkOut
                                      : AttendanceAction.checkIn,
                                ),
                              ),
                            ).then(
                              (_) => context.read<AttendanceState>().refresh(
                                fetchRemote: false,
                              ),
                            );
                          },
                    icon: const Icon(Icons.location_on_rounded),
                    label: Text(
                      todayOut
                          ? 'Completed'
                          : todayIn
                          ? 'Check Out'
                          : 'Check In',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildMonthSummary(theme, isDark, records),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _buildCalendar(theme, isDark, records),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Attendance Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Text(
                      _selectedDateTitle(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSelectedDayCard(theme, isDark, records),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: Text(
                  'Status Guide',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: _buildStatusGuide(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool showBackButton) {
    return Row(
      children: [
        if (showBackButton) ...[
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Track your workdays and attendance history.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.12, end: 0);
  }

  Widget _buildMonthSummary(
    ThemeData theme,
    bool isDark,
    Map<String, _AttendanceRecord> records,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF29214F), Color(0xFF1C2545)]
              : const [Color(0xFF6548E8), Color(0xFF8871F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white70,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'MONTHLY OVERVIEW',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _monthTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryMetric(
                value: records.values
                    .where(
                      (r) =>
                          r.checkIn != '--:--' &&
                          r.status != _RecordStatus.rejected,
                    )
                    .length
                    .toString()
                    .padLeft(2, '0'),
                label: 'Present days',
              ),
              _summaryDivider(),
              _SummaryMetric(
                value: records.values
                    .where((r) => r.status == _RecordStatus.pending)
                    .length
                    .toString()
                    .padLeft(2, '0'),
                label: 'Pending',
              ),
              _summaryDivider(),
              _SummaryMetric(
                value: records.values
                    .where((r) => r.status == _RecordStatus.rejected)
                    .length
                    .toString()
                    .padLeft(2, '0'),
                label: 'Rejected',
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _summaryDivider() {
    return Container(
      height: 38,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildCalendar(
    ThemeData theme,
    bool isDark,
    Map<String, _AttendanceRecord> records,
  ) {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);

    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;

    // Monday = 0, Sunday = 6.
    final leadingDays = firstDay.weekday - 1;
    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 17, 15, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _monthTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _MonthArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _changeMonth(-1),
              ),
              const SizedBox(width: 8),
              _MonthArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: weekdays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.48,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingDays + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(
                _displayedMonth.year,
                _displayedMonth.month,
                dayNumber,
              );

              final record = records[_dateKey(date)];
              final selected = _dateKey(date) == _dateKey(_selectedDate);

              return _CalendarDay(
                day: dayNumber,
                selected: selected,
                record: record,
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Divider(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            height: 1,
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CalendarLegend(color: AppColors.success, label: 'Present'),
              const SizedBox(width: 18),
              _CalendarLegend(color: AppColors.warning, label: 'Pending'),
              const SizedBox(width: 18),
              _CalendarLegend(color: AppColors.error, label: 'Rejected'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildSelectedDayCard(
    ThemeData theme,
    bool isDark,
    Map<String, _AttendanceRecord> records,
  ) {
    final record = _selectedRecord(records);

    if (record == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 38,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'No attendance records',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'There are no attendance entries for this date.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Record',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedDateTitle(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _RecordStatusBadge(status: record.status),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TimeDetail(
                  icon: Icons.login_rounded,
                  label: 'Check In',
                  value: record.checkIn,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeDetail(
                  icon: Icons.logout_rounded,
                  label: 'Check Out',
                  value: record.checkOut,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceSecondary
                  : AppColors.lightSurfaceSecondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 19,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 9),
                Text(
                  'Working Duration',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  record.duration,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _buildStatusGuide(ThemeData theme) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: const [
        _GuideChip(
          color: AppColors.success,
          label: 'Synced',
          icon: Icons.cloud_done_rounded,
        ),
        _GuideChip(
          color: AppColors.warning,
          label: 'Pending Sync',
          icon: Icons.cloud_upload_rounded,
        ),
        _GuideChip(
          color: AppColors.error,
          label: 'Rejected',
          icon: Icons.cloud_off_rounded,
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark
          ? AppColors.darkSurfaceSecondary
          : AppColors.lightSurfaceSecondary,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: SizedBox(
          width: 35,
          height: 35,
          child: Icon(
            icon,
            size: 21,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final int day;
  final bool selected;
  final _AttendanceRecord? record;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.day,
    required this.selected,
    required this.record,
    required this.onTap,
  });

  Color? get _dotColor {
    final currentRecord = record;

    if (currentRecord == null) return null;

    switch (currentRecord.status) {
      case _RecordStatus.synced:
        return AppColors.success;
      case _RecordStatus.pending:
        return AppColors.warning;
      case _RecordStatus.rejected:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color:
                      _dotColor ??
                      (selected
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.transparent),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TimeDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TimeDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceSecondary
            : AppColors.lightSurfaceSecondary,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordStatusBadge extends StatelessWidget {
  final _RecordStatus status;

  const _RecordStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _RecordStatus.synced => AppColors.success,
      _RecordStatus.pending => AppColors.warning,
      _RecordStatus.rejected => AppColors.error,
    };

    final label = switch (status) {
      _RecordStatus.synced => 'Synced',
      _RecordStatus.pending => 'Pending',
      _RecordStatus.rejected => 'Rejected',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == _RecordStatus.synced
                ? Icons.check_circle_rounded
                : status == _RecordStatus.pending
                ? Icons.schedule_rounded
                : Icons.error_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideChip extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;

  const _GuideChip({
    required this.color,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _RecordStatus { synced, pending, rejected }

class _AttendanceRecord {
  final String checkIn;
  final String checkOut;
  final String duration;
  final _RecordStatus status;

  const _AttendanceRecord({
    required this.checkIn,
    required this.checkOut,
    required this.duration,
    required this.status,
  });
}
