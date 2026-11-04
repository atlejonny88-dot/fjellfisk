import 'package:flutter/material.dart';

import '../l10n/localizations.dart';

class DashboardRefreshWarning extends StatelessWidget {
  const DashboardRefreshWarning({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF2D58A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF9A6700)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.dashboardShowingLastSavedData,
              style: const TextStyle(
                color: Color(0xFF624600),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
  }
}
