import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum StatusType { success, warning, error, info, pending, offline }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType status;
  final IconData? icon;
  final bool animate;

  const StatusBadge({
    super.key,
    required this.label,
    required this.status,
    this.icon,
    this.animate = true,
  });

  Color get _background {
    switch (status) {
      case StatusType.success:
        return AppColors.successLight;
      case StatusType.warning:
      case StatusType.pending:
        return AppColors.warningLight;
      case StatusType.error:
        return AppColors.errorLight;
      case StatusType.info:
        return AppColors.infoLight;
      case StatusType.offline:
        return const Color(0xFFE9EAF0);
    }
  }

  Color get _foreground {
    switch (status) {
      case StatusType.success:
        return AppColors.success;
      case StatusType.warning:
      case StatusType.pending:
        return const Color(0xFFB87912);
      case StatusType.error:
        return AppColors.error;
      case StatusType.info:
        return AppColors.info;
      case StatusType.offline:
        return const Color(0xFF73788D);
    }
  }

  IconData get _icon {
    if (icon != null) return icon!;

    switch (status) {
      case StatusType.success:
        return Icons.check_circle_rounded;
      case StatusType.warning:
        return Icons.warning_rounded;
      case StatusType.error:
        return Icons.cancel_rounded;
      case StatusType.info:
        return Icons.info_rounded;
      case StatusType.pending:
        return Icons.schedule_rounded;
      case StatusType.offline:
        return Icons.wifi_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final foreground = isDark && status == StatusType.success
        ? AppColors.successDark
        : _foreground;

    final background = isDark
        ? foreground.withValues(alpha: 0.13)
        : _background;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (animate)
            _AnimatedStatusIcon(icon: _icon, color: foreground)
          else
            Icon(_icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _AnimatedStatusIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(icon),
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Icon(icon, size: 13, color: color),
    );
  }
}
