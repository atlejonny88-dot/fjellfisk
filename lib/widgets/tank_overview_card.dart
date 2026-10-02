import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/localizations.dart';
import '../utils/ui_motion.dart';

class TankOverviewCard extends StatefulWidget {
  const TankOverviewCard({
    super.key,
    required this.name,
    required this.isActive,
    required this.fishCountLabel,
    required this.biomassLabel,
    required this.weightLabel,
    required this.feedLabel,
    required this.mortalityLabel,
    required this.temperatureLabel,
    required this.statusLabel,
    required this.statusMessage,
    required this.statusColor,
    required this.statusIcon,
    required this.onTap,
    this.onDelete,
    this.noteText,
    this.noteMeta,
    this.onNoteTap,
    this.notesUnavailable = false,
    this.reviewed = false,
  });

  final String name;
  final bool isActive;
  final String fishCountLabel;
  final String biomassLabel;
  final String weightLabel;
  final String feedLabel;
  final String mortalityLabel;
  final String temperatureLabel;
  final String statusLabel;
  final String statusMessage;
  final Color statusColor;
  final IconData statusIcon;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String? noteText;
  final String? noteMeta;
  final VoidCallback? onNoteTap;
  final bool notesUnavailable;
  final bool reviewed;

  @override
  State<TankOverviewCard> createState() => _TankOverviewCardState();
}

class _TankOverviewCardState extends State<TankOverviewCard> {
  bool _shown = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final duration = uiMotionDuration(context);
    final reduceMotion = uiMotionDisabled(context);
    final canHover =
        kIsWeb && MediaQuery.sizeOf(context).width >= 700 && !reduceMotion;
    final borderColor =
        widget.isActive ? const Color(0xFFDCE5EF) : const Color(0xFFD4DAE2);

    return AnimatedOpacity(
      duration: duration,
      curve: Curves.easeOut,
      opacity: reduceMotion || _shown ? 1 : 0,
      child: AnimatedScale(
        duration: duration,
        curve: Curves.easeOutCubic,
        scale: canHover && _hovering
            ? 1.012
            : (reduceMotion || _shown ? 1 : 0.996),
        child: MouseRegion(
          cursor: canHover ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: canHover ? (_) => setState(() => _hovering = true) : null,
          onExit: canHover ? (_) => setState(() => _hovering = false) : null,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: widget.isActive ? Colors.white : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: canHover && _hovering
                    ? const Color(0xFFB5D1EE)
                    : borderColor,
              ),
              boxShadow: _hovering
                  ? const [
                      BoxShadow(
                        color: Color(0x16082C51),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x0A082C51),
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TankCardHeader(
                        name: widget.name,
                        statusLabel: widget.statusLabel,
                        statusColor: widget.statusColor,
                        onDelete: widget.onDelete,
                      ),
                      AnimatedSize(
                        duration: duration,
                        curve: Curves.easeOut,
                        child: AnimatedSwitcher(
                          duration: duration,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.97, end: 1)
                                  .animate(animation),
                              alignment: Alignment.centerLeft,
                              child: child,
                            ),
                          ),
                          child: widget.reviewed
                              ? Padding(
                                  key: const ValueKey('reviewed'),
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline,
                                          size: 16, color: Color(0xFF557268)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          l10n.reviewedThisSession,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF557268),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(key: ValueKey('not-reviewed')),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TankVisualSummary(
                        isActive: widget.isActive,
                        fishCountLabel: widget.fishCountLabel,
                        biomassLabel: widget.biomassLabel,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _TankMetric(
                              icon: Icons.monitor_weight_outlined,
                              label: l10n.averageWeight,
                              value: widget.weightLabel,
                              isMuted: !widget.isActive,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _TankMetric(
                              icon: Icons.inventory_2_outlined,
                              label: l10n.feedLast24Hours,
                              value: widget.feedLabel,
                              isMuted: !widget.isActive,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _TankMetric(
                              icon: Icons.heart_broken_outlined,
                              label: l10n.deathsLast7DaysShort,
                              value: widget.mortalityLabel,
                              color:
                                  widget.statusColor == const Color(0xFFD53C3C)
                                      ? widget.statusColor
                                      : null,
                              isMuted: !widget.isActive,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _TankMetric(
                              icon: Icons.device_thermostat_outlined,
                              label: l10n.temperature,
                              value: widget.temperatureLabel,
                              isMuted: !widget.isActive,
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: duration,
                        curve: Curves.easeOut,
                        child: AnimatedSwitcher(
                          duration: duration,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -0.03),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: widget.noteText != null
                              ? Padding(
                                  key: ValueKey(
                                    'note-${widget.noteText}-${widget.noteMeta}',
                                  ),
                                  padding: const EdgeInsets.only(top: 10),
                                  child: _NoteStrip(
                                    text: widget.noteText!,
                                    meta: widget.noteMeta,
                                    onTap: widget.onNoteTap,
                                  ),
                                )
                              : widget.notesUnavailable
                                  ? const Padding(
                                      key: ValueKey('notes-unavailable'),
                                      padding: EdgeInsets.only(top: 10),
                                      child: _UnavailableNotesStrip(),
                                    )
                                  : const SizedBox(key: ValueKey('no-note')),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _StatusStrip(
                        label: widget.statusMessage,
                        color: widget.statusColor,
                        icon: widget.statusIcon,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TankCardHeader extends StatelessWidget {
  const _TankCardHeader({
    required this.name,
    required this.statusLabel,
    required this.statusColor,
    required this.onDelete,
  });

  final String name;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0A1733),
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (onDelete != null) ...[
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: context.l10n.moreOptions,
            icon: const Icon(Icons.more_horiz, size: 21),
            onSelected: (value) {
              if (value == 'delete') onDelete!();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Color(0xFFD53C3C)),
                    const SizedBox(width: 8),
                    Text(context.l10n.deleteTank),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TankVisualSummary extends StatelessWidget {
  const _TankVisualSummary({
    required this.isActive,
    required this.fishCountLabel,
    required this.biomassLabel,
  });

  final bool isActive;
  final String fishCountLabel;
  final String biomassLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: ColorFiltered(
              colorFilter: isActive
                  ? const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.dst,
                    )
                  : const ColorFilter.matrix(<double>[
                      0.33,
                      0.33,
                      0.33,
                      0,
                      0,
                      0.33,
                      0.33,
                      0.33,
                      0,
                      0,
                      0.33,
                      0.33,
                      0.33,
                      0,
                      0,
                      0,
                      0,
                      0,
                      0.68,
                      0,
                    ]),
              child: Image.asset(
                'assets/images/aquaculture_tank.png',
                fit: BoxFit.contain,
                cacheWidth: 512,
                semanticLabel: context.l10n.tankIllustration,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrimaryMetric(
                  icon: Icons.set_meal_outlined,
                  label: fishCountLabel,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.biomass,
                  style: const TextStyle(
                    color: Color(0xFF708096),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                _PrimaryMetric(
                  icon: Icons.scale_outlined,
                  label: biomassLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryMetric extends StatelessWidget {
  const _PrimaryMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF0B63E5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0A1733),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TankMetric extends StatelessWidget {
  const _TankMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.isMuted,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isMuted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground =
        isMuted ? const Color(0xFF7F8997) : color ?? const Color(0xFF173C67);

    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: isMuted ? const Color(0xFFE8EBEF) : const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color?.withValues(alpha: 0.18) ?? const Color(0xFFE7EDF4),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: foreground),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteStrip extends StatelessWidget {
  const _NoteStrip({
    required this.text,
    required this.meta,
    required this.onTap,
  });

  final String text;
  final String? meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF2D58A)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.sticky_note_2_outlined,
              size: 17,
              color: Color(0xFFB57800),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF624600),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (meta != null)
                    Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8A6B24),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _UnavailableNotesStrip extends StatelessWidget {
  const _UnavailableNotesStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 15, color: Color(0xFF7F8997)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            context.l10n.tankNotesUnavailable,
            style: const TextStyle(color: Color(0xFF7F8997), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 19, color: color),
        ],
      ),
    );
  }
}
