import 'package:flutter/material.dart';

class TankRegistrationActions extends StatelessWidget {
  const TankRegistrationActions({
    super.key,
    required this.canWrite,
    required this.isActive,
    required this.saving,
    required this.openingNext,
    required this.hasSaved,
    required this.onSave,
    required this.onSaveNext,
    required this.onNext,
    required this.onInfo,
    required this.onWeightSample,
    required this.onMove,
    required this.onHistory,
    required this.onGrowth,
    required this.onMortality,
  });

  final bool canWrite, isActive, saving, openingNext, hasSaved;
  final VoidCallback onSave, onSaveNext, onNext, onInfo, onWeightSample;
  final VoidCallback onMove, onHistory, onGrowth, onMortality;

  @override
  Widget build(BuildContext context) {
    final busy = saving || openingNext;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canWrite && isActive) ...[
          ElevatedButton.icon(
            onPressed: busy ? null : onSave,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(saving ? 'Lagrer…' : 'Lagre'),
          ),
          ElevatedButton.icon(
            onPressed: busy ? null : onSaveNext,
            icon: const Icon(Icons.skip_next_outlined, size: 18),
            label: const Text('Lagre og neste'),
          ),
        ],
        if (hasSaved && canWrite)
          OutlinedButton.icon(
            onPressed: busy ? null : onNext,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(openingNext ? 'Åpner neste…' : 'Neste kar'),
          ),
        for (final action in <(String, IconData, VoidCallback)>[
          ('Kar info', Icons.info_outline, onInfo),
          ('Vektprøve', Icons.monitor_weight_outlined, onWeightSample),
          if (canWrite && isActive) ('Flytt fisk', Icons.swap_horiz, onMove),
          ('Historikk', Icons.history, onHistory),
          ('Vekstdiagram', Icons.show_chart, onGrowth),
          ('Dødelighetsdiagram', Icons.bar_chart, onMortality),
        ])
          OutlinedButton.icon(
            onPressed: busy ? null : action.$3,
            icon: Icon(action.$2, size: 18),
            label: Text(action.$1),
          ),
      ],
    );
  }
}
