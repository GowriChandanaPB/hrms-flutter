import 'package:flutter/material.dart';

class PageTransitions {
  PageTransitions._();

  static Route<T> slideFade<T>(
    Widget page, {
    Offset beginOffset = const Offset(0.08, 0),
    Duration duration = const Duration(milliseconds: 450),
  }) {
    return PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Route<T> scaleFade<T>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    return PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
