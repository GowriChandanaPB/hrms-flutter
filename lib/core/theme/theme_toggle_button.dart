import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_colors.dart';
import 'theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();

    final isDark = controller.isDarkMode;

    return Tooltip(
      message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: IconButton(
        onPressed: controller.toggleTheme,
        style: IconButton.styleFrom(
          backgroundColor: isDark
              ? AppColors.darkSurfaceSecondary
              : AppColors.primarySoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return RotationTransition(
              turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
            );
          },
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            color: isDark ? AppColors.accent : AppColors.primary,
            size: 21,
          ),
        ),
      ),
    );
  }
}
