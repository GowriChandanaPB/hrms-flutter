import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AnimatedButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;
  final double height;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color foregroundColor;

  const AnimatedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.height = 54,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor = Colors.white,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _pressed = false;

  bool get _isEnabled =>
      widget.enabled && !widget.isLoading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ?? AppColors.primaryGradient;

    return GestureDetector(
      onTap: _isEnabled ? widget.onPressed : null,
      onTapDown: _isEnabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _isEnabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.gradient == null ? widget.backgroundColor : null,
            gradient: widget.gradient == null
                ? null
                : _isEnabled
                ? gradient
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: _pressed ? 0.12 : 0.24,
                      ),
                      blurRadius: _pressed ? 6 : 16,
                      offset: Offset(0, _pressed ? 2 : 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: widget.isLoading
                  ? SizedBox(
                      key: ValueKey('loading'),
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.foregroundColor,
                        ),
                      ),
                    )
                  : Row(
                      key: const ValueKey('content'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: 19,
                            color: widget.foregroundColor,
                          ),
                          const SizedBox(width: 9),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.foregroundColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
