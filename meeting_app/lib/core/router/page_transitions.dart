import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum PageTransitionType { fade, slide, scale, sharedAxis }

CustomTransitionPage<T> buildTransitionPage<T>({
  required LocalKey key,
  required Widget child,
  PageTransitionType type = PageTransitionType.fade,
  Duration duration = const Duration(milliseconds: 350),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return switch (type) {
        PageTransitionType.fade => FadeTransition(
          opacity: curved,
          child: child,
        ),
        PageTransitionType.slide => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        ),
        PageTransitionType.scale => ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        ),
        PageTransitionType.sharedAxis => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        ),
      };
    },
  );
}
