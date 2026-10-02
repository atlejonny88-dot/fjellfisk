import 'package:flutter/material.dart';

import '../l10n/localizations.dart';
import '../utils/ui_motion.dart';

class TankRegistrationActions extends StatelessWidget {
  const TankRegistrationActions({
    super.key,
    required this.canWrite,
    required this.isActive,
    required this.saving,
    required this.openingNext,
    required this.hasSaved,
    this.showSavedFeedback = false,
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
  final bool showSavedFeedback;
  final VoidCallback onSave, onSaveNext, onNext, onInfo, onWeightSample;
  final VoidCallback onMove, onHistory, onGrowth, onMortality;

  @override
  Widget build(BuildContext context) {
    final busy = saving || openingNext;
    final duration = uiMotionDuration(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: showSavedFeedback
                ? Padding(
                    key: const ValueKey('registration-saved'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF8F0),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: Color(0xFF16875A),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            context.l10n.registrationSaved,
                            style: const TextStyle(
                              color: Color(0xFF176441),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('registration-not-saved')),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canWrite && isActive) ...[
              ElevatedButton.icon(
                onPressed: busy ? null : onSave,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(saving ? context.l10n.saving : context.l10n.save),
              ),
              ElevatedButton.icon(
                onPressed: busy ? null : onSaveNext,
                icon: const Icon(Icons.skip_next_outlined, size: 18),
                label: Text(context.l10n.saveAndNext),
              ),
            ],
            if (hasSaved && canWrite)
              OutlinedButton.icon(
                onPressed: busy ? null : onNext,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(openingNext
                    ? context.l10n.openingNext
                    : context.l10n.nextTank),
              ),
            for (final action in <(String, IconData, VoidCallback)>[
              (context.l10n.tankInfo, Icons.info_outline, onInfo),
              (
                context.l10n.weightSamples,
                Icons.monitor_weight_outlined,
                onWeightSample
              ),
              if (canWrite && isActive)
                (context.l10n.moveFish, Icons.swap_horiz, onMove),
              (context.l10n.history, Icons.history, onHistory),
              (context.l10n.growthChart, Icons.show_chart, onGrowth),
              (context.l10n.mortalityChart, Icons.bar_chart, onMortality),
            ])
              OutlinedButton.icon(
                onPressed: busy ? null : action.$3,
                icon: Icon(action.$2, size: 18),
                label: Text(action.$1),
              ),
          ],
        ),
      ],
    );
  }
}
