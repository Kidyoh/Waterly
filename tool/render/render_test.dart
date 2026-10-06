// Renders app screens to PNG for screenshots and banners. Not part of the
// normal test run; use: flutter test tool/render --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waterly/main.dart';
import 'package:waterly/water_store.dart';

Future<void> _fonts() async {
  final manrope = File('assets/fonts/Manrope.ttf').readAsBytesSync();
  await (FontLoader(
    'Manrope',
  )..addFont(Future.value(ByteData.sublistView(manrope)))).load();
  final flutterRoot = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent.parent.parent.path;
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(icons)))).load();
}

String _key(int daysAgo) {
  final now = DateTime.now();
  return WaterStore.dayKey(DateTime(now.year, now.month, now.day - daysAgo));
}

Map<String, Object> _history(List<int> todayMl, {bool reminders = false}) {
  final t = DateTime.now()
      .copyWith(hour: 12, minute: 31)
      .millisecondsSinceEpoch;
  String day(List<int> ml) => jsonEncode([
    for (final a in ml) {'a': a, 't': t},
  ]);
  return {
    'entries_${_key(0)}': day(todayMl),
    'entries_${_key(1)}': day([500, 750, 750]),
    'entries_${_key(2)}': day([1000, 1000, 250]),
    'entries_${_key(3)}': day([750, 750, 500]),
    'entries_${_key(4)}': day([500, 500, 250]),
    'entries_${_key(5)}': day([1000, 1000]),
    'entries_${_key(6)}': day([1500, 250]),
    'reminders': reminders,
  };
}

Future<void> _setUp(
  WidgetTester tester,
  Map<String, Object> prefs,
  double gx,
) async {
  await tester.runAsync(_fonts);
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(prefs);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
    (_) async => null,
  );
  tester.binding.defaultBinaryMessenger.setMockStreamHandler(
    const EventChannel('dev.fluttercommunity.plus/sensors/accelerometer'),
    MockStreamHandler.inline(
      onListen: (args, sink) => sink.success([gx, 9.6, 0.0, 0.0]),
    ),
  );
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _snap(WidgetTester tester, String name) =>
    expectLater(find.byType(WaterlyApp), matchesGoldenFile('out/$name.png'));

void main() {
  testWidgets('main', (tester) async {
    await _setUp(tester, _history([250, 250, 250, 250, 150]), -1.2);
    await tester.pumpWidget(const WaterlyApp());
    await _frames(tester, 240);
    await _snap(tester, 'main');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tilt', (tester) async {
    await _setUp(tester, _history([250, 250, 250, 250, 150]), -3.2);
    await tester.pumpWidget(const WaterlyApp());
    await _frames(tester, 240);
    await tester.tap(find.text('250 ml'));
    await _frames(tester, 25);
    await _snap(tester, 'tilt');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('goal', (tester) async {
    await _setUp(tester, _history([500, 500, 500, 250]), 1.0);
    await tester.pumpWidget(const WaterlyApp());
    await _frames(tester, 240);
    await tester.tap(find.text('250 ml'));
    await _frames(tester, 40);
    await _snap(tester, 'goal');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings', (tester) async {
    await _setUp(tester, _history([250, 250, 150], reminders: true), 0);
    await tester.pumpWidget(const WaterlyApp());
    await _frames(tester, 200);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await _frames(tester, 40);
    await _snap(tester, 'settings');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('history', (tester) async {
    await _setUp(tester, _history([250, 250, 250, 150, 500, 250]), 0);
    await tester.pumpWidget(const WaterlyApp());
    await _frames(tester, 200);
    await tester.drag(find.text('Today'), const Offset(0, -420));
    await _frames(tester, 60);
    await _snap(tester, 'history');
    await tester.pumpWidget(const SizedBox());
  });
}
