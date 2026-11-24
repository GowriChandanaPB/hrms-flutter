import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/status_badge.dart';
import '../../sync/services/attendance_sync_coordinator.dart';

class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sync = context.watch<AttendanceSyncCoordinator>();
    final pending = sync.pendingCount;
    final hasRejected = sync.rejectedCount > 0;
    final indicatorColor = pending > 0
        ? AppColors.warning
        : hasRejected
        ? AppColors.error
        : AppColors.success;
    final status = pending > 0
        ? StatusType.pending
        : hasRejected
        ? StatusType.error
        : StatusType.success;

    return AppCard(
      padding: const EdgeInsets.all(15),
      animate: true,
      animationIndex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: indicatorColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.cloud_upload_rounded,
              color: indicatorColor,
              size: 22,
            ),
          ),

          const SizedBox(height: 13),

          Text(
            'Sync Status',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: 7),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (pending > 0) const _PendingIndicator(),
              if (pending > 0) const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$pending Pending · ${sync.syncedCount} Synced',
                  maxLines: 2,
                  softWrap: true,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          StatusBadge(
            label: pending > 0
                ? 'Pending Sync'
                : hasRejected
                ? 'Rejected Events'
                : 'All Synced',
            status: status,
          ),
        ],
      ),
    );
  }
}

class _PendingIndicator extends StatelessWidget {
  const _PendingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: AppColors.warning,
            shape: BoxShape.circle,
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: 0.35, end: 1, duration: 900.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.25, 1.25),
          duration: 900.ms,
        );
  }
}
