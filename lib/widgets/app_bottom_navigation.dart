import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../features/attendance/attendance_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/leave/leave_screen.dart';
import '../features/sync/sync_screen.dart';

class AppBottomNavigation extends StatefulWidget {
  const AppBottomNavigation({super.key});

  @override
  State<AppBottomNavigation> createState() =>
      _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation> {
  late final PageController _pageController;

  int _selectedIndex = 0;

  final List<_NavigationItem> _items = const [
    _NavigationItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavigationItem(
      label: 'Attendance',
      icon: Icons.access_time_outlined,
      selectedIcon: Icons.access_time_filled_rounded,
    ),
    _NavigationItem(
      label: 'Leaves',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    _NavigationItem(
      label: 'Sync',
      icon: Icons.sync_outlined,
      selectedIcon: Icons.sync_rounded,
    ),
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    AttendanceScreen(),
    LeaveScreen(),
    SyncScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      initialPage: 0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: _screens.length,
        physics: const BouncingScrollPhysics(),
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          return _screens[index];
        },
      ),
      bottomNavigationBar: _buildNavigationBar(isDark),
    );
  }

  Widget _buildNavigationBar(bool isDark) {
    final background = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    final selectedColor = isDark
        ? AppColors.primaryLight
        : AppColors.primary;

    final unselectedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.18)
                : AppColors.lightShadow,
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          child: Row(
            children: List.generate(
              _items.length,
              (index) {
                final selected = _selectedIndex == index;

                return Expanded(
                  child: _NavigationDestination(
                    item: _items[index],
                    selected: selected,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    isDark: isDark,
                    onTap: () => _selectTab(index),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _NavigationDestination extends StatelessWidget {
  final _NavigationItem item;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final bool isDark;
  final VoidCallback onTap;

  const _NavigationDestination({
    required this.item,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? isDark
                    ? const Color(0xFF393265)
                    : AppColors.primarySoft
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                scale: selected ? 1.13 : 1,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    key: ValueKey(selected),
                    color: selected
                        ? selectedColor
                        : unselectedColor,
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(height: 5),

              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                style: TextStyle(
                  color: selected
                      ? selectedColor
                      : unselectedColor,
                  fontSize: selected ? 11 : 10,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 3),

              // FIXED WIDTH INDICATOR
              // Never animate width from 16 to 0.
              // Animate opacity and scale instead.

              SizedBox(
                height: 3,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: selected ? 1 : 0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      scale: selected ? 1 : 0.2,
                      child: Container(
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}