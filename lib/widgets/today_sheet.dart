import 'package:flutter/material.dart';

import '../theme.dart';
import '../water_store.dart';
import 'week_strip.dart';

/// The lavender "Today" card listing every drink logged today.
class TodaySheet extends StatelessWidget {
  const TodaySheet({
    super.key,
    required this.store,
    required this.controller,
    required this.onDelete,
  });

  final WaterStore store;
  final ScrollController controller;
  final ValueChanged<WaterEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [WaterColors.sheet, WaterColors.sheetBottom],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final entries = store.entries;
          return ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(28, 26, 28, 24 + bottom),
            children: [
              Row(
                children: [
                  Text(
                    'Today',
                    style: manrope(
                      30,
                      weight: FontWeight.w500,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: WeekStrip(
                          days: store.recentDays(7),
                          streak: store.streak,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Nothing yet — tap + to log a drink',
                    style: manrope(
                      13,
                      color: WaterColors.ink.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              for (final e in entries)
                Dismissible(
                  key: ObjectKey(e),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => onDelete(e),
                  background: Container(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Delete',
                      style: manrope(
                        13,
                        weight: FontWeight.w600,
                        color: const Color(0xFFB2405E),
                      ),
                    ),
                  ),
                  child: _EntryRow(entry: e),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final WaterEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = entry.time;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: WaterColors.ink.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Water (+${entry.amount})',
            style: manrope(
              13,
              weight: FontWeight.w500,
              color: WaterColors.ink.withValues(alpha: 0.85),
            ),
          ),
          const Spacer(),
          Text(
            time,
            style: manrope(
              13,
              weight: FontWeight.w500,
              color: WaterColors.ink.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
