import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waterly/onboarding_screen.dart';
import 'package:waterly/theme.dart';
import 'package:waterly/water_screen.dart';
import 'package:waterly/water_sim.dart';
import 'package:waterly/water_store.dart';
import 'package:flutter/material.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('formatMl adds thousands separators', () {
    expect(formatMl(0), '0');
    expect(formatMl(650), '650');
    expect(formatMl(1150), '1,150');
    expect(formatMl(1234567), '1,234,567');
  });

  test('store adds, removes and restores entries', () async {
    final store = WaterStore();
    await store.load();
    store.add(250);
    store.add(150);
    expect(store.total, 400);
    expect(store.entries.first.amount, 150);

    final entry = store.entries.first;
    final index = store.remove(entry);
    expect(store.total, 250);
    store.restore(index, entry);
    expect(store.total, 400);

    // Persisted for the next launch.
    final reloaded = WaterStore();
    await reloaded.load();
    expect(reloaded.total, 400);
  });

  test('sim rises towards the target and caps the percentage', () {
    final sim = WaterSim()
      ..layout(const Size(390, 844), EdgeInsets.zero, 640)
      ..pourIn(2150, 2000);
    for (var i = 0; i < 600; i++) {
      sim.step(1 / 60);
    }
    expect(sim.level, closeTo(1.075, 0.01));
    expect(sim.percent, 100);
    expect(sim.shownMl, 2150);
  });

  test('surface tilts against the roll of the phone', () {
    final sim = WaterSim()..layout(const Size(400, 800), EdgeInsets.zero, 600);
    // Right edge of the phone pointing down: gravity reaction has -x.
    sim.setGravity(-4, 9);
    for (var i = 0; i < 600; i++) {
      sim.step(1 / 60);
    }
    // Water climbs the lower (right) side of the screen.
    expect(sim.surfaceY(390), lessThan(sim.surfaceY(10)));
  });

  testWidgets('tapping +150 logs a drink', (tester) async {
    final store = WaterStore();
    await tester.pumpWidget(
      MaterialApp(home: WaterScreen(store: store, useSensors: false)),
    );
    await tester.pump();

    await tester.tap(find.text('150 ml'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.total, 150);
    expect(find.text('Water (+150)'), findsOneWidget);
  });

  testWidgets('onboarding saves the goal and opens the tracker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen(useSensors: false)),
    );
    await tester.pump();

    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.tap(find.text('Skip'));
    await frames(20);
    expect(find.text('2,000'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2,250'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await frames(30);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(OnboardingScreen.doneKey), isTrue);
    expect(prefs.getInt('goal'), 2250);
    expect(find.byType(WaterScreen), findsOneWidget);
  });
}
