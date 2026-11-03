import 'package:flutter/material.dart';

/// Keeps app routes above Android's system navigation and keyboard insets.
class MobileNavigationSafeArea extends StatelessWidget {
  const MobileNavigationSafeArea({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: false, left: false, right: false, child: child),
    );
  }
}
