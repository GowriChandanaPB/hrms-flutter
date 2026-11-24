import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/connectivity_monitor.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/calendar_date.dart';
import '../../data/models/leave_balance_model.dart';
import '../../data/models/leave_request_model.dart';
import 'services/leave_service.dart';
import 'services/leave_validation.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  LeaveType? _leaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  LeaveBalanceModel? _balance;
  String? _typeError;
  String? _startDateError;
  String? _endDateError;
  String? _overlapError;
  String? _balanceError;
  bool _isLoadingBalance = true;
  bool _hasAttemptedSubmit = false;
  ConnectivityMonitor? _connectivityMonitor;

  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBalance());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final monitor = context.read<ConnectivityMonitor>();
    if (identical(monitor, _connectivityMonitor)) return;
    _connectivityMonitor?.removeListener(_onConnectivityChanged);
    _connectivityMonitor = monitor;
    monitor.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (_connectivityMonitor?.isOnline == true) _refreshBalance();
  }

  @override
  void dispose() {
    _connectivityMonitor?.removeListener(_onConnectivityChanged);
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _refreshBalance() async {
    try {
      final balance = await context.read<LeaveService>().getLeaveBalance();
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _isLoadingBalance = false;
        _updateBalanceError();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingBalance = false;
        _balanceError = error.toString();
      });
    }
  }

  void _updateDateErrors() {
    final today = LeaveValidation.companyToday(DateTime.now());
    _startDateError = _startDate == null
        ? _hasAttemptedSubmit
              ? 'Select a start date.'
              : null
        : LeaveValidation.startDateError(_startDate!, today);
    _endDateError = _endDate == null
        ? _hasAttemptedSubmit
              ? 'Select an end date.'
              : null
        : _startDate == null
        ? null
        : LeaveValidation.endDateError(_startDate!, _endDate!);
    _overlapError = null;
    _updateBalanceError();
  }

  void _updateBalanceError() {
    if (_startDate == null || _endDate == null || _leaveType == null) {
      _balanceError = null;
      return;
    }
    if (_balance == null) return;

    final requestedDays = LeaveValidation.requestedDays(_startDate!, _endDate!);
    final availableDays = _leaveType == LeaveType.casual
        ? _balance!.casualLeave
        : _balance!.sickLeave;
    _balanceError = requestedDays > availableDays
        ? 'Requested $requestedDays days exceeds the available $availableDays days.'
        : null;
  }

  int get _totalDays {
    if (_startDate == null || _endDate == null) return 0;
    return LeaveValidation.requestedDays(_startDate!, _endDate!);
  }

  Future<void> _selectDate({required bool isStart}) async {
    final now = LeaveValidation.companyToday(DateTime.now());
    final selectedStart = _startDate == null ? now : calendarDate(_startDate!);
    final minimumDate = isStart || selectedStart.isBefore(now)
        ? now
        : selectedStart;

    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: minimumDate,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = picked;

        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
      _updateDateErrors();
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';

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

    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!context.read<ConnectivityMonitor>().isOnline) {
      _showMessage(
        'You are offline. Leave requests require an internet connection.',
      );
      return;
    }

    final reasonIsValid = _formKey.currentState!.validate();
    var datesAreValid = false;
    setState(() {
      _hasAttemptedSubmit = true;
      _typeError = _leaveType == null ? 'Select a leave type.' : null;
      _updateDateErrors();
      datesAreValid = _startDateError == null && _endDateError == null;
      _updateBalanceError();
    });

    if (_leaveType == null || !datesAreValid || !reasonIsValid) return;

    if (_balance == null) {
      _showMessage(_balanceError ?? 'Leave balance is unavailable.');
      return;
    }

    if (_balanceError != null) return;

    setState(() => _isSubmitting = true);

    try {
      final leaveService = context.read<LeaveService>();

      final request = await leaveService.submitLeaveRequest(
        type: _leaveType!,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, request);
    } catch (error) {
      if (!mounted) return;
      if (error is LeaveException && error.field != null) {
        switch (error.field!) {
          case LeaveValidationField.startDate:
            setState(() {
              _startDateError = error.message;
            });
          case LeaveValidationField.endDate:
            setState(() {
              _endDateError = error.message;
            });
          case LeaveValidationField.leaveType:
            setState(() {
              _typeError = error.message;
            });
          case LeaveValidationField.balance:
            setState(() {
              _balanceError = error.message;
            });
          case LeaveValidationField.overlap:
            setState(() {
              _overlapError = error.message;
            });
          case LeaveValidationField.reason:
          case LeaveValidationField.connectivity:
            _showMessage(error.message);
        }
      } else {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isOnline = context.watch<ConnectivityMonitor>().isOnline;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Apply for Leave',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Text(
              'Take a break when you need it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.58),
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
            if (!isOnline) ...[
              const SizedBox(height: 14),
              _offlineNotice(theme),
            ],
            const SizedBox(height: 24),

            _label('Leave Type', theme),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _typeOption(
                    title: 'Casual Leave',
                    subtitle: 'Personal time off',
                    icon: Icons.beach_access_rounded,
                    selected: _leaveType == LeaveType.casual,
                    onTap: () => setState(() {
                      _leaveType = LeaveType.casual;
                      _typeError = null;
                      _updateBalanceError();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _typeOption(
                    title: 'Sick Leave',
                    subtitle: 'Health and recovery',
                    icon: Icons.medical_services_rounded,
                    selected: _leaveType == LeaveType.sick,
                    onTap: () => setState(() {
                      _leaveType = LeaveType.sick;
                      _typeError = null;
                      _updateBalanceError();
                    }),
                  ),
                ),
              ],
            ),

            if (_typeError != null) _fieldError(_typeError!, colors.error),
            const SizedBox(height: 8),
            Text(
              _isLoadingBalance
                  ? 'Loading leave balance...'
                  : _balance == null
                  ? _balanceError ?? 'Leave balance unavailable.'
                  : 'Available: ${_leaveType == LeaveType.sick
                        ? _balance!.sickLeave
                        : _leaveType == LeaveType.casual
                        ? _balance!.casualLeave
                        : 'select a leave type'} days',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _balanceError == null
                    ? colors.onSurface.withValues(alpha: 0.62)
                    : colors.error,
              ),
            ),

            const SizedBox(height: 25),

            _label('Leave Duration', theme),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _dateField(
                    title: 'START DATE',
                    date: _startDate,
                    error: _startDateError,
                    onTap: () => _selectDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateField(
                    title: 'END DATE',
                    date: _endDate,
                    error: _endDateError,
                    onTap: () => _selectDate(isStart: false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Total leave days',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '$_totalDays ${_totalDays == 1 ? 'day' : 'days'}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            if (_overlapError != null)
              _fieldError(_overlapError!, colors.error),
            if (_balanceError != null)
              _fieldError(_balanceError!, colors.error),

            const SizedBox(height: 25),

            _label('Reason for Leave', theme),
            const SizedBox(height: 10),

            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Tell us why you need leave...',
                alignLabelWithHint: true,
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(
                    color: colors.outline.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(
                    color: colors.outline.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                return LeaveValidation.reasonError(value ?? '');
              },
            ),

            const SizedBox(height: 12),

            const SizedBox(height: 25),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting || !isOnline ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isSubmitting
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          key: ValueKey('submit'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 19),
                            SizedBox(width: 9),
                            Text(
                              'Submit Leave Request',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, ThemeData theme) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _typeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.09)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : theme.colorScheme.outline.withValues(alpha: 0.18),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 23),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : Colors.grey,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({
    required String title,
    required DateTime? date,
    String? error,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _formatDate(date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (error != null) _fieldError(error, theme.colorScheme.error),
      ],
    );
  }

  Widget _fieldError(String message, Color color) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Text(message, style: TextStyle(color: color, fontSize: 12)),
  );

  Widget _offlineNotice(ThemeData theme) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      'Offline: cached balance may be out of date. Connect to submit; '
      'leave requests are not saved for later submission.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    ),
  );
}
