import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_toggle_button.dart';
import '../../../data/models/employee_model.dart';
import '../../../data/repositories/employee_repository.dart';

class EmployeeHeader extends StatefulWidget {
  const EmployeeHeader({super.key});

  @override
  State<EmployeeHeader> createState() => _EmployeeHeaderState();
}

class _EmployeeHeaderState extends State<EmployeeHeader> {
  Future<EmployeeModel>? _employeeFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _employeeFuture ??= context.read<EmployeeRepository>().getEmployee();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<EmployeeModel>(
      future: _employeeFuture,
      builder: (context, snapshot) {
        final employee = snapshot.data;
        final identityColor = isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                        _greeting(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: identityColor,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 5),
                  Text(
                    employee?.name ??
                        (snapshot.hasError ? 'Employee' : 'Loading...'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15, end: 0),
                  if (employee != null) ...[
                    const SizedBox(height: 5),
                    Text(
                          [
                            employee.id,
                            employee.department,
                          ].where((value) => value.isNotEmpty).join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: identityColor,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.12, end: 0),
                  ],
                ],
              ),
            ),
            const ThemeToggleButton(),
            const SizedBox(width: 8),
            _ProfileAvatar(employeeName: employee?.name ?? ''),
          ],
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String employeeName;

  const _ProfileAvatar({required this.employeeName});

  @override
  Widget build(BuildContext context) {
    final initials = employeeName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(
          begin: const Offset(0.65, 0.65),
          end: const Offset(1, 1),
          duration: 650.ms,
          curve: Curves.easeOutBack,
        );
  }
}
