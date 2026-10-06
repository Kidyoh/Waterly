import 'package:flutter/material.dart';

import '../theme.dart';
import '../water_store.dart';

/// Goal, cup sizes and reminders, in one small sheet.
Future<void> showSettingsSheet(
  BuildContext context, {
  required WaterStore store,
  required VoidCallback onEditGoal,
  required ValueChanged<int> onEditCup,
  required ValueChanged<ReminderSettings> onRemindersChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: store,
      builder: (context, _) => _SettingsSheet(
        store: store,
        onEditGoal: onEditGoal,
        onEditCup: onEditCup,
        onRemindersChanged: onRemindersChanged,
      ),
    ),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.store,
    required this.onEditGoal,
    required this.onEditCup,
    required this.onRemindersChanged,
  });

  final WaterStore store;
  final VoidCallback onEditGoal;
  final ValueChanged<int> onEditCup;
  final ValueChanged<ReminderSettings> onRemindersChanged;

  @override
  Widget build(BuildContext context) {
    final r = store.reminders;
    final muted = WaterColors.ink.withValues(alpha: 0.5);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [WaterColors.sheet, WaterColors.sheetBottom],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: WaterColors.ink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Settings',
            style: manrope(26, weight: FontWeight.w500, letterSpacing: -0.4),
          ),
          const SizedBox(height: 8),
          _Row(
            label: 'Daily goal',
            child: _Chip(
              label: '${formatMl(store.goal)} ml',
              onTap: onEditGoal,
            ),
          ),
          _Row(
            label: 'Cup sizes',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < store.cups.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _Chip(
                    label: '${formatMl(store.cups[i])} ml',
                    onTap: () => onEditCup(i),
                  ),
                ],
              ],
            ),
          ),
          _Row(
            label: 'Reminders',
            sublabel: 'Quiet when you’re on track',
            child: Switch(
              value: r.enabled,
              activeTrackColor: WaterColors.bgMid,
              onChanged: (on) => onRemindersChanged(r.copyWith(enabled: on)),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !r.enabled
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      _Row(
                        label: 'Between',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Chip(
                              label: _hour(r.startHour),
                              onTap: () => _pickHour(
                                context,
                                r.startHour,
                                (h) => onRemindersChanged(
                                  r.copyWith(
                                    startHour: h,
                                    endHour: h < r.endHour ? null : h + 1,
                                  ),
                                ),
                                max: 22,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '–',
                                style: manrope(15, color: muted),
                              ),
                            ),
                            _Chip(
                              label: _hour(r.endHour),
                              onTap: () => _pickHour(
                                context,
                                r.endHour,
                                (h) => onRemindersChanged(
                                  r.copyWith(
                                    endHour: h,
                                    startHour: h > r.startHour ? null : h - 1,
                                  ),
                                ),
                                min: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Row(
                        label: 'Every',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final h in const [1, 2, 3]) ...[
                              if (h > 1) const SizedBox(width: 8),
                              _Chip(
                                label: '${h}h',
                                selected: r.everyHours == h,
                                onTap: () => onRemindersChanged(
                                  r.copyWith(everyHours: h),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _hour(int h) => '${h.toString().padLeft(2, '0')}:00';

  Future<void> _pickHour(
    BuildContext context,
    int current,
    ValueChanged<int> onPicked, {
    int min = 0,
    int max = 23,
  }) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: WaterColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var h = min; h <= max; h++)
                _Chip(
                  label: _hour(h),
                  selected: h == current,
                  onTap: () => Navigator.pop(context, h),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onPicked(picked);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child, this.sublabel});

  final String label;
  final String? sublabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: WaterColors.ink.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: manrope(15, weight: FontWeight.w600)),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: manrope(
                      12,
                      color: WaterColors.ink.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? WaterColors.ink
              : WaterColors.ink.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: manrope(
            13,
            weight: FontWeight.w600,
            color: selected ? Colors.white : WaterColors.ink,
          ),
        ),
      ),
    );
  }
}
