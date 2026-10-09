import 'package:flutter/material.dart';

import '../theme.dart';
import '../water_store.dart';

/// A streak chip and seven tiny glasses, one per day, filled to that
/// day's level. Today is the last glass.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.days, required this.streak});

  final List<DayTotal> days;
  final int streak;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (streak > 0) ...[
          Tooltip(
            message: '$streak-day streak',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: WaterColors.ink.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 14,
                    color: Color(0xFFE0612F),
                  ),
                  const SizedBox(width: 3),
                  Text('$streak', style: manrope(12, weight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Tooltip(
            message:
                '${_weekdays[days[i].day.weekday - 1]} · '
                '${formatMl(days[i].total)} ml',
            child: _MiniGlass(day: days[i], isToday: i == days.length - 1),
          ),
        ],
      ],
    );
  }
}

class _MiniGlass extends StatelessWidget {
  const _MiniGlass({required this.day, required this.isToday});

  final DayTotal day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.only(
      topLeft: Radius.circular(3),
      topRight: Radius.circular(3),
      bottomLeft: Radius.circular(6),
      bottomRight: Radius.circular(6),
    );
    return Container(
      width: 14,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: WaterColors.ink.withValues(alpha: isToday ? 0.85 : 0.2),
          width: isToday ? 1.6 : 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            widthFactor: 1,
            heightFactor: day.progress.clamp(0.0, 1.0),
            child: ColoredBox(
              color: day.met ? WaterColors.bgMid : WaterColors.waterBody,
            ),
          ),
        ),
      ),
    );
  }
}
