import 'package:flutter/material.dart';

/// Approved Fjellfisk wordmark for light surfaces.
class FjellfiskLogo extends StatelessWidget {
  const FjellfiskLogo({
    super.key,
    required this.height,
    this.alignment = Alignment.centerLeft,
  });

  final double height;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Fjellfisk',
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/images/branding/fjellfisk_logo.png',
          height: height,
          alignment: alignment,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
