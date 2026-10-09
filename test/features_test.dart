import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waterly/reminders.dart';
import 'package:waterly/water_screen.dart';
import 'package:waterly/water_sim.dart';
import 'package:waterly/water_store.dart';

String _key(int daysAgo) {
  final now = DateTime.now();
  return WaterStore.dayKey(DateTime(now.year, now.month, now.day - daysAgo));
}

String _entries(List<int> amounts) => jsonEncode([
  for (final a in amounts) {'a': a, 't': 0},
]);

void main() {
  group('history', () {
    test('streak counts met days in a row, today only once met', () async {
      SharedPreferences.setMockInitialValues({
        'entries_${_key(1)}': _entries([2000]),
        'entries_${_key(2)}': _entries([1000, 1200]),
        'entries_${_key(3)}': _entries([500]), // missed: streak stops here
        'entries_${_key(4)}': _entries([3000]),
      });
      final store = WaterStore();
      await store.load();
      expect(store.streak, 2);

      store.add(2000);
      expect(store.streak, 3);
    });

    test('past days keep the goal they had', () async {
      SharedPreferences.setMockInitialValues({
        'entries_${_key(1)}': _entries([1500]),
        'goal_${_key(1)}': 1500,
      });
      final store = WaterStore();
      await store.load();
      store.setGoal(3000);

      final days = store.recentDays(7);
      expect(days, hasLength(7));
      expect(days[5].total, 1500);
      expect(days[5].met, isTrue);
      expect(days.last.goal, 3000);
      expect(store.streak, 1);
    });

    test('reload picks up drinks logged by the widget', () async {
      SharedPreferences.setMockInitialValues({});
      final store = WaterStore();
      await store.load();
      store.add(250);

      // What WaterData.add on Android does: newest first, same key.
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonDecode(prefs.getString('entries_${_key(0)}')!) as List;
      await prefs.setString(
        'entries_${_key(0)}',
        jsonEncode([
          {'a': 330, 't': DateTime.now().millisecondsSinceEpoch},
          ...raw,
        ]),
      );

      await store.reload();
      expect(store.total, 580);
      expect(store.entries.first.amount, 330);
    });

    test('cup sizes and reminder settings persist', () async {
      SharedPreferences.setMockInitialValues({});
      final store = WaterStore();
      await store.load();
      expect(store.cups, [150, 250]);
      store.setCup(1, 330);
      store.setReminders(
        const ReminderSettings(enabled: true, startHour: 8, everyHours: 3),
      );

      final reloaded = WaterStore();
      await reloaded.load();
      expect(reloaded.cups, [150, 330]);
      expect(reloaded.reminders.enabled, isTrue);
      expect(reloaded.reminders.startHour, 8);
      expect(reloaded.reminders.everyHours, 3);
    });
  });

  group('reminder plan', () {
    const on = ReminderSettings(enabled: true); // 9–21, every 2h
    final morning = DateTime(2026, 10, 7, 7, 30);

    List<int> hoursToday(List<PlannedReminder> plan, DateTime now) => [
      for (final r in plan)
        if (r.time.day == now.day) r.time.hour,
    ];

    test('nothing when disabled', () {
      expect(
        planReminders(
          now: morning,
          settings: const ReminderSettings(),
          total: 0,
          goal: 2000,
        ),
        isEmpty,
      );
    });

    test('every slot in the hours when nothing drunk yet', () {
      final plan = planReminders(
        now: morning,
        settings: on,
        total: 0,
        goal: 2000,
      );
      expect(hoursToday(plan, morning), [9, 11, 13, 15, 17, 19, 21]);
      // Plus the next two days.
      expect(plan, hasLength(21));
      expect(plan.first.body, contains('Start'));
    });

    test('quiet while on track, and right after a drink', () {
      final noon = DateTime(2026, 10, 7, 12, 0);
      final plan = planReminders(
        now: noon,
        settings: on,
        total: 1000, // ahead of pace until 15:00
        goal: 2000,
        lastDrink: noon,
      );
      // 13:00 is within 90 min of the drink; 15:00 needs exactly 1000 ml.
      expect(hoursToday(plan, noon), [17, 19, 21]);
      expect(plan.first.body, contains('1,000 of 2,000'));
    });

    test('nothing more today once the goal is met', () {
      final noon = DateTime(2026, 10, 7, 12, 0);
      final plan = planReminders(
        now: noon,
        settings: on,
        total: 2000,
        goal: 2000,
      );
      expect(hoursToday(plan, noon), isEmpty);
      expect(plan, hasLength(14));
    });
  });

  test('celebrate surges the water and fills it with bubbles', () {
    final sim = WaterSim()
      ..layout(const Size(390, 844), EdgeInsets.zero, 640)
      ..setTotals(1900, 2000);
    for (var i = 0; i < 300; i++) {
      sim.step(1 / 60);
    }
    sim.celebrate();
    expect(sim.slosh, greaterThan(1));
    expect(sim.bubbles.length, greaterThan(20));
  });

  testWidgets('long-press a cup to change its size', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = WaterStore();
    await tester.pumpWidget(
      MaterialApp(home: WaterScreen(store: store, useSensors: false)),
    );
    await tester.pump();

    await tester.longPress(find.text('250 ml'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('330 ml'));
    await tester.tap(find.text('Save cup'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(store.cups, [150, 330]);
    await tester.tap(find.text('330 ml'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.total, 330);
  });
}
