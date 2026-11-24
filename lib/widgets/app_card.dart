import 'package:flutter/material.dart';

import '../core/animations/app_animations.dart';
import '../core/theme/app_colors.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool animate;
  final int animationIndex;
  final double radius;
  final bool showBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.backgroundColor,
    this.onTap,
    this.animate = false,
    this.animationIndex = 0,
    this.radius = 18,
    this.showBorder = true,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = AnimatedScale(
      scale: _pressed && widget.onTap != null ? 0.985 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.gradient == null
              ? widget.backgroundColor ??
                    (isDark ? AppColors.darkSurface : AppColors.lightSurface)
              : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.showBorder
              ? Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.18)
                  : AppColors.lightShadow,
              blurRadius: _pressed ? 5 : 18,
              offset: Offset(0, _pressed ? 2 : 6),
            ),
          ],
        ),
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );

    final interactiveContent = widget.onTap == null
        ? content
        : GestureDetector(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: content,
          );

    if (!widget.animate) {
      return interactiveContent;
    }

    return AppAnimations.staggered(
      interactiveContent,
      index: widget.animationIndex,
    );
  }
}
