import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppAnimations {
  AppAnimations._();

  // Fade and slide upwards
  static Widget fadeSlide(
    Widget child, {
    Duration duration = const Duration(milliseconds: 650),
    Duration delay = Duration.zero,
    double beginOffset = 0.10,
  }) {
    return child
        .animate()
        .fadeIn(duration: duration, delay: delay, curve: Curves.easeOutCubic)
        .slide(
          begin: Offset(0, beginOffset),
          end: Offset.zero,
          duration: duration,
          delay: delay,
          curve: Curves.easeOutCubic,
        );
  }

  // Scale entrance animation
  static Widget popIn(
    Widget child, {
    Duration duration = const Duration(milliseconds: 500),
    Duration delay = Duration.zero,
  }) {
    return child
        .animate()
        .fadeIn(duration: duration, delay: delay)
        .scale(
          begin: const Offset(0.88, 0.88),
          end: const Offset(1, 1),
          duration: duration,
          delay: delay,
          curve: Curves.easeOutBack,
        );
  }

  // Staggered card entrance
  static Widget staggered(
    Widget child, {
    required int index,
    Duration duration = const Duration(milliseconds: 550),
    int delayMilliseconds = 90,
  }) {
    return fadeSlide(
      child,
      duration: duration,
      delay: Duration(milliseconds: index * delayMilliseconds),
    );
  }

  // Slide from right
  static Widget slideFromRight(
    Widget child, {
    Duration duration = const Duration(milliseconds: 550),
    Duration delay = Duration.zero,
  }) {
    return child
        .animate()
        .fadeIn(duration: duration, delay: delay)
        .slide(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
          duration: duration,
          delay: delay,
          curve: Curves.easeOutCubic,
        );
  }

  // Continuous subtle pulse
  static Widget pulse(
    Widget child, {
    Duration duration = const Duration(milliseconds: 1200),
    double scale = 1.04,
  }) {
    return child
        .animate(
          onPlay: (controller) {
            controller.repeat(reverse: true);
          },
        )
        .scale(
          begin: const Offset(1, 1),
          end: Offset(scale, scale),
          duration: duration,
          curve: Curves.easeInOut,
        );
  }

  // Button entrance
  static Widget buttonEntrance(
    Widget child, {
    Duration duration = const Duration(milliseconds: 450),
  }) {
    return child
        .animate()
        .fadeIn(duration: duration)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: duration,
          curve: Curves.easeOutBack,
        );
  }
}
