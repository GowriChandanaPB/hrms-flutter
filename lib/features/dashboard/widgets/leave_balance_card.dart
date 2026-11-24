import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_balance_model.dart';
import '../../leave/services/leave_service.dart';
import '../../../widgets/app_card.dart';

class LeaveBalanceCard extends StatefulWidget {
  const LeaveBalanceCard({super.key});

  @override
  State<LeaveBalanceCard> createState() => _LeaveBalanceCardState();
}

class _LeaveBalanceCardState extends State<LeaveBalanceCard> {
  Future<LeaveBalanceModel>? _balanceFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _balanceFuture ??= context.read<LeaveService>().getLeaveBalance();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(15),
      animate: true,
      animationIndex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ).animate().scale(
            begin: const Offset(0.7, 0.7),
            end: const Offset(1, 1),
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),

          const SizedBox(height: 13),

          Text(
            'Leave Balance',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),

          const SizedBox(height: 5),

          FutureBuilder<LeaveBalanceModel>(
            future: _balanceFuture,
            builder: (context, snapshot) {
              final totalAvailable = snapshot.data?.totalAvailable;
              if (snapshot.connectionState == ConnectionState.waiting &&
                  totalAvailable == null) {
                return Text(
                  'Loading...',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                );
              }
              if (snapshot.hasError || totalAvailable == null) {
                return Text(
                  'Unavailable',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                );
              }

              return TweenAnimationBuilder<double>(
                key: ValueKey(totalAvailable),
                tween: Tween(begin: 0, end: totalAvailable.toDouble()),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Text(
                  '${value.toStringAsFixed(0)} Days',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 5),

          Text(
            'Casual + Sick',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
