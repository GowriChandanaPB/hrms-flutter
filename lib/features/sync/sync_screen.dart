import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/attendance_event_model.dart';
import 'services/attendance_sync_coordinator.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
  }

  Future<void> _loadEvents() async {
    try {
      await context.read<AttendanceSyncCoordinator>().refreshCounts();

      if (!mounted) return;

      setState(() {
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load attendance events.';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    try {
      final coordinator = context.read<AttendanceSyncCoordinator>();
      final result = await coordinator.syncPendingEvents();

      await _loadEvents();

      if (!mounted) return;

      final message = result == null
          ? (coordinator.lastError ?? 'No pending events to synchronize.')
          : result.error ??
                (result.remaining > 0
                    ? '${result.synced} synced, ${result.rejected} rejected, '
                          '${result.remaining} still pending.'
                    : '${result.synced} event(s) synced successfully.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync could not be completed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) await _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final syncState = context.watch<AttendanceSyncCoordinator>();
    final currentEvents = syncState.events.reversed.toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadEvents,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _header(theme),
                    const SizedBox(height: 24),
                    _connectionCard(colors, syncState),
                    if (syncState.lastError != null) ...[
                      const SizedBox(height: 10),
                      _messageCard(
                        theme,
                        icon: Icons.info_outline_rounded,
                        message: syncState.lastError!,
                      ),
                    ],
                    if (syncState.isSyncing) ...[
                      const SizedBox(height: 10),
                      Text(
                        syncState.isAutomaticSync
                            ? 'Automatic synchronization is running…'
                            : 'Manual synchronization is running…',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (syncState.lastSuccessfulSync != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last successful sync: ${syncState.lastSuccessfulSync}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 22),
                    _sectionTitle(
                      'Sync Overview',
                      'Your local attendance activity',
                      theme,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            context,
                            syncState.pendingCount.toString().padLeft(2, '0'),
                            'Pending',
                            Icons.cloud_upload_rounded,
                            AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _metricCard(
                            context,
                            syncState.syncedCount.toString().padLeft(2, '0'),
                            'Synced',
                            Icons.cloud_done_rounded,
                            AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _metricCard(
                            context,
                            syncState.rejectedCount.toString().padLeft(2, '0'),
                            'Rejected',
                            Icons.cloud_off_rounded,
                            AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 27),
                    _sectionTitle(
                      'Attendance Activity',
                      'Events stored on this device',
                      theme,
                    ),
                    const SizedBox(height: 13),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(35),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _messageCard(
                        theme,
                        icon: Icons.error_outline_rounded,
                        message: _error!,
                      )
                    else if (currentEvents.isEmpty)
                      _messageCard(
                        theme,
                        icon: Icons.cloud_sync_rounded,
                        message:
                            'No attendance events yet. Your activity will '
                            'appear here after checking in or out.',
                      )
                    else
                      ...currentEvents.map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _eventCard(
                            context,
                            event: event,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    const SizedBox(height: 13),
                    _syncInformation(theme),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed:
                            syncState.isSyncing || syncState.pendingCount == 0
                            ? null
                            : _syncNow,
                        icon: syncState.isSyncing
                            ? const SizedBox(
                                height: 19,
                                width: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(
                          syncState.isSyncing ? 'Syncing...' : 'Sync Now',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.35,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.08),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Pending events remain saved on this device.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sync Center',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Keep your workspace data up to date.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.sync_rounded, color: AppColors.primary),
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _connectionCard(ColorScheme colors, AttendanceSyncCoordinator state) {
    final onlineColor = state.isOnline ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25204E), Color(0xFF171D38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: onlineColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.cloud_sync_rounded, color: onlineColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Sync',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  state.isOnline
                      ? 'Network available'
                      : 'Offline · saved locally',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: onlineColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              state.isOnline ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                color: onlineColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.08);
  }

  Widget _sectionTitle(String title, String subtitle, ThemeData theme) {
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

  Widget _metricCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _eventCard(
    BuildContext context, {
    required AttendanceEventModel event,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    final isCheckIn = event.type == AttendanceEventType.checkIn;

    final status = switch (event.syncStatus) {
      AttendanceSyncStatus.pending => 'Pending',
      AttendanceSyncStatus.synced => 'Synced',
      AttendanceSyncStatus.rejected => 'Rejected',
    };

    final statusColor = switch (event.syncStatus) {
      AttendanceSyncStatus.pending => AppColors.warning,
      AttendanceSyncStatus.synced => AppColors.success,
      AttendanceSyncStatus.rejected => AppColors.error,
    };

    final icon = isCheckIn ? Icons.login_rounded : Icons.logout_rounded;

    final title = isCheckIn ? 'Attendance Check In' : 'Attendance Check Out';

    final date = event.timestamp;
    final dateText =
        '${date.day.toString().padLeft(2, '0')} '
        '${_monthName(date.month)} ${date.year}';

    final timeText =
        '${(date.hour % 12 == 0 ? 12 : date.hour % 12).toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')} '
        '${date.hour >= 12 ? 'PM' : 'AM'}';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
              .withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateText • $timeText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          _statusBadge(status, statusColor),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.04);
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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

  Widget _messageCard(
    ThemeData theme, {
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncInformation(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Pending attendance events remain saved locally. '
              'They are sent in their original order when you synchronize.',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
