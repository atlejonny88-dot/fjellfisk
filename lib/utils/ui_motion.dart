import 'package:flutter/material.dart';

const Duration kUiMotionDuration = Duration(milliseconds: 180);

bool uiMotionDisabled(BuildContext context) {
  return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

Duration uiMotionDuration(
  BuildContext context, {
  Duration duration = kUiMotionDuration,
}) {
  return uiMotionDisabled(context) ? Duration.zero : duration;
}

Route<T> subtleFadeSlideRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final duration = uiMotionDuration(
    context,
    duration: const Duration(milliseconds: 220),
  );
  if (duration == Duration.zero) {
    return MaterialPageRoute<T>(builder: builder);
  }

  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (routeContext, _, __) => builder(routeContext),
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
            begin: const Offset(0.012, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
