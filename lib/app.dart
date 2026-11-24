import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'widgets/app_bottom_navigation.dart';

class RebsHrmsApp extends StatelessWidget {
  const RebsHrmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,

          themeAnimationDuration: const Duration(milliseconds: 450),
          themeAnimationCurve: Curves.easeInOutCubic,

          home: const AppBottomNavigation(),
        );
      },
    );
  }
}
