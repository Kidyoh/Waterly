import 'package:flutter/material.dart';

import '../theme.dart';

/// Bottom sheet for picking an amount in ml. Returns null if dismissed.
Future<int?> showAmountSheet(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
  required int step,
  required List<int> presets,
  required String action,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AmountSheet(
      title: title,
      initial: initial.clamp(min, max),
      min: min,
      max: max,
      step: step,
      presets: presets,
      action: action,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    required this.step,
    required this.presets,
    required this.action,
  });

  final String title;
  final int initial;
  final int min;
  final int max;
  final int step;
  final List<int> presets;
  final String action;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) {
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
            widget.title,
            style: manrope(26, weight: FontWeight.w500, letterSpacing: -0.4),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatMl(_value),
                  style: manrope(
                    56,
                    weight: FontWeight.w600,
                    letterSpacing: -2,
                  ),
                ),
                TextSpan(
                  text: ' ml',
                  style: manrope(
                    24,
                    weight: FontWeight.w500,
                    color: WaterColors.ink.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: WaterColors.bgMid,
              inactiveTrackColor: WaterColors.ink.withValues(alpha: 0.1),
              thumbColor: WaterColors.bgMid,
              overlayColor: WaterColors.bgMid.withValues(alpha: 0.12),
              trackHeight: 6,
            ),
            child: Slider(
              value: _value.toDouble(),
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              divisions: (widget.max - widget.min) ~/ widget.step,
              onChanged: (v) => setState(() => _value = v.round()),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in widget.presets)
                _Preset(
                  label: '${formatMl(p)} ml',
                  selected: p == _value,
                  onTap: () => setState(() => _value = p),
                ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: WaterColors.lime,
                foregroundColor: WaterColors.ink,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(context, _value),
              child: Text(
                widget.action,
                style: manrope(16, weight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
              : WaterColors.ink.withValues(alpha: 0.06),
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
