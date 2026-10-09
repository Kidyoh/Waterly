import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'theme.dart';
import 'water_store.dart';

class PlannedReminder {
  const PlannedReminder(this.time, this.title, this.body);

  final DateTime time;
  final String title;
  final String body;
}

const _titles = ['Time for a glass 💧', 'Sip break', 'Your glass is waiting'];

/// Works out which reminders to send over the next [days] days.
///
/// The plan is rebuilt every time a drink is logged, so today's reminders
/// know the current total: they are skipped once the goal is met, within
/// 90 minutes of the last drink, and whenever you're ahead of an even pace
/// through the reminder hours.
List<PlannedReminder> planReminders({
  required DateTime now,
  required ReminderSettings settings,
  required int total,
  required int goal,
  DateTime? lastDrink,
  int days = 3,
}) {
  final start = settings.startHour;
  final end = settings.endHour;
  if (!settings.enabled || settings.everyHours <= 0 || end <= start) {
    return const [];
  }
  final plan = <PlannedReminder>[];
  for (var d = 0; d < days; d++) {
    for (var h = start; h <= end; h += settings.everyHours) {
      final time = DateTime(now.year, now.month, now.day + d, h);
      if (!time.isAfter(now)) continue;
      final title = _titles[plan.length % _titles.length];

      if (d > 0) {
        plan.add(
          PlannedReminder(
            time,
            title,
            h == start
                ? 'Good morning! Start the day with a glass of water.'
                : 'A few sips now keeps you on track.',
          ),
        );
        continue;
      }

      if (total >= goal) continue;
      if (lastDrink != null &&
          time.difference(lastDrink) < const Duration(minutes: 90)) {
        continue;
      }
      final expected = goal * (h - start) / (end - start);
      if (total > 0 && total >= expected) continue;
      plan.add(
        PlannedReminder(
          time,
          title,
          total == 0
              ? 'Start with a glass of water.'
              : 'You’re at ${formatMl(total)} of ${formatMl(goal)} ml. '
                    'A glass now keeps you on track.',
        ),
      );
    }
  }
  return plan;
}

/// Local notifications for drink reminders.
class Reminders {
  Reminders._();

  static final instance = Reminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Gentle nudges to drink water',
      color: WaterColors.bgBottom,
    ),
    iOS: DarwinNotificationDetails(),
  );

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_waterly'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks for permission to notify. Returns false if refused.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await _init();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  /// Replaces all scheduled reminders with a fresh plan for [store].
  Future<void> reschedule(WaterStore store) async {
    if (!_supported) return;
    await _init();
    await _plugin.cancelAll();
    final plan = planReminders(
      now: DateTime.now(),
      settings: store.reminders,
      total: store.total,
      goal: store.goal,
      lastDrink: store.lastDrink,
    );
    for (var i = 0; i < plan.length; i++) {
      await _plugin.zonedSchedule(
        id: i,
        // One-off reminders only need the instant, so UTC avoids needing
        // the device's time zone name.
        scheduledDate: tz.TZDateTime.from(plan[i].time, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: plan[i].title,
        body: plan[i].body,
      );
    }
  }
}
