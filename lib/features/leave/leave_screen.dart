
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/connectivity_monitor.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/calendar_date.dart';
import '../../data/models/leave_balance_model.dart';
import '../../data/models/leave_request_model.dart';
import 'apply_leave_screen.dart';
import 'services/leave_service.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  late Future<_LeaveData> _leaveDataFuture;
  ConnectivityMonitor? _connectivityMonitor;
  bool _wasOnline = false;

  @override
  void initState() {
    super.initState();
    _loadLeaveData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final monitor = context.read<ConnectivityMonitor>();
    if (identical(monitor, _connectivityMonitor)) return;
    _connectivityMonitor?.removeListener(_onConnectivityChanged);
    _connectivityMonitor = monitor;
    _wasOnline = monitor.isOnline;
    monitor.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    final isOnline = _connectivityMonitor?.isOnline ?? false;
    if (isOnline && !_wasOnline && mounted) {
      setState(_loadLeaveData);
    }
    _wasOnline = isOnline;
  }

  @override
  void dispose() {
    _connectivityMonitor?.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _loadLeaveData() {
    _leaveDataFuture = _fetchLeaveData();
  }

  Future<_LeaveData> _fetchLeaveData() async {
    final service = context.read<LeaveService>();

    final results = await Future.wait([
      service.getLeaveBalance(),
      service.getLeaveRequests(),
    ]);

    return _LeaveData(
      balance: results[0] as LeaveBalanceModel,
      requests: results[1] as List<LeaveRequestModel>,
    );
  }

  Future<void> _refresh() async {
    setState(_loadLeaveData);
    await _leaveDataFuture;
  }

  Future<void> _openApplyLeave() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ApplyLeaveScreen(),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(_loadLeaveData);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]}, ${date.year}';
  }

  String _formatDateRange(LeaveRequestModel request) {
    final start = _formatDate(request.startDate);
    final end = _formatDate(request.endDate);

    if (DateUtils.isSameDay(request.startDate, request.endDate)) {
      return start;
    }

    return '$start – $end';
  }

  int _requestDays(LeaveRequestModel request) {
    return inclusiveCalendarDays(request.startDate, request.endDate);
  }

  String _leaveTypeName(LeaveType type) {
    return type == LeaveType.casual ? 'Casual Leave' : 'Sick Leave';
  }

  String _statusName(LeaveRequestStatus status) {
    switch (status) {
      case LeaveRequestStatus.pending:
        return 'Pending';
      case LeaveRequestStatus.approved:
        return 'Approved';
      case LeaveRequestStatus.rejected:
        return 'Rejected';
    }
  }

  Color _statusColor(LeaveRequestStatus status) {
    switch (status) {
      case LeaveRequestStatus.pending:
        return AppColors.warning;
      case LeaveRequestStatus.approved:
        return AppColors.success;
      case LeaveRequestStatus.rejected:
        return AppColors.error;
    }
  }

  IconData _leaveIcon(LeaveType type) {
    return type == LeaveType.casual
        ? Icons.beach_access_rounded
        : Icons.medical_services_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isOnline = context.watch<ConnectivityMonitor>().isOnline;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: FutureBuilder<_LeaveData>(
            future: _leaveDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error);
              }

              final data = snapshot.data!;

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _header(context, colors),
                        if (!isOnline) ...[
                          const SizedBox(height: 14),
                          _offlineBanner(theme),
                        ],
                        const SizedBox(height: 24),
                        _balanceCard(data.balance),
                        const SizedBox(height: 24),
                        _sectionTitle(
                          'Leave Overview',
                          'Your available leave balance',
                          theme,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _leaveBalance(
                                context,
                                title: 'Casual Leave',
                                balance: data.balance.casualLeave.toString(),
                                subtitle: 'available days',
                                icon: Icons.beach_access_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _leaveBalance(
                                context,
                                title: 'Sick Leave',
                                balance: data.balance.sickLeave.toString(),
                                subtitle: 'available days',
                                icon: Icons.medical_services_rounded,
                                color: AppColors.info,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: _sectionTitle(
                                'Recent Requests',
                                'Your leave application history',
                                theme,
                              ),
                            ),
                            TextButton(
                              onPressed: _refresh,
                              child: const Text('Refresh'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (data.requests.isEmpty)
                          _emptyRequests(context)
                        else
                          ...data.requests.map(
                                (request) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _requestCard(context, request),
                                ),
                              ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _openApplyLeave,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(
                              'Apply for Leave',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.08),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load leave information',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                setState(_loadLeaveData);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Plan your time off with ease.',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.58),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: AppColors.primary,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.10);
  }

  Widget _balanceCard(LeaveBalanceModel balance) {
    final total = balance.totalAvailable;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6044E8), Color(0xFF8B72F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'TOTAL AVAILABLE LEAVES',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateTime.now().year.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 9, bottom: 6),
                child: Text(
                  'days remaining',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: total > 0 ? 1 : 0,
              minHeight: 7,
              backgroundColor: const Color(0x55FFFFFF),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$total days available',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              const Text(
                'Casual + Sick',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.10);
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _leaveBalance(
    BuildContext context, {
    required String title,
    required String balance,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
              .withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            balance,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms).scale(
          begin: const Offset(0.96, 0.96),
          duration: 350.ms,
        );
  }

  Widget _emptyRequests(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_note_rounded,
            size: 38,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            'No leave requests yet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Your submitted leave applications will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Offline: showing cached leave balance and requests. This information '
        'may not be current. Reconnect and refresh to update it.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _requestCard(
    BuildContext context,
    LeaveRequestModel request,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusColor(request.status);
    final days = _requestDays(request);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
              .withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _leaveIcon(request.type),
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_leaveTypeName(request.type)} • '
                  '${_formatDateRange(request)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statusBadge(
                      _statusName(request.status),
                      statusColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$days ${days == 1 ? 'day' : 'days'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.05);
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LeaveData {
  final LeaveBalanceModel balance;
  final List<LeaveRequestModel> requests;

  const _LeaveData({
    required this.balance,
    required this.requests,
  });
}
