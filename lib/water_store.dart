import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single logged drink.
class WaterEntry {
  WaterEntry(this.amount, this.time);

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
    json['a'] as int,
    DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
  );

  final int amount;
  final DateTime time;

  Map<String, dynamic> toJson() => {
    'a': amount,
    't': time.millisecondsSinceEpoch,
  };
}

/// One day's total against that day's goal.
class DayTotal {
  const DayTotal(this.day, this.total, this.goal);

  final DateTime day;
  final int total;
  final int goal;

  double get progress => goal <= 0 ? 0 : total / goal;
  bool get met => goal > 0 && total >= goal;
}

/// When to nudge the user to drink.
class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.startHour = 9,
    this.endHour = 21,
    this.everyHours = 2,
  });

  final bool enabled;

  /// First and last reminder of the day, in local hours (0–23).
  final int startHour;
  final int endHour;
  final int everyHours;

  ReminderSettings copyWith({
    bool? enabled,
    int? startHour,
    int? endHour,
    int? everyHours,
  }) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    startHour: startHour ?? this.startHour,
    endHour: endHour ?? this.endHour,
    everyHours: everyHours ?? this.everyHours,
  );
}

/// Today's intake, the daily goal and preferences, persisted on device.
///
/// Entries are stored per calendar day, so a new day starts empty. Each
/// day also keeps the goal it had, so past days and streaks stay correct
/// after the goal changes.
class WaterStore extends ChangeNotifier {
  static const defaultGoal = 2000;
  static const defaultCups = [150, 250];

  SharedPreferences? _prefs;
  String _day = dayKey(DateTime.now());

  int goal = defaultGoal;

  /// Sizes of the two quick-add buttons, in ml.
  List<int> cups = List.of(defaultCups);

  ReminderSettings reminders = const ReminderSettings();

  /// Today's entries, newest first.
  List<WaterEntry> entries = [];

  int get total => entries.fold(0, (sum, e) => sum + e.amount);

  DateTime? get lastDrink => entries.isEmpty ? null : entries.first.time;

  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    goal = prefs.getInt('goal') ?? defaultGoal;
    final savedCups = prefs.getStringList('cups');
    if (savedCups != null && savedCups.length == defaultCups.length) {
      cups = savedCups.map(int.parse).toList();
    }
    reminders = ReminderSettings(
      enabled: prefs.getBool('reminders') ?? false,
      startHour: prefs.getInt('reminders_start') ?? 9,
      endHour: prefs.getInt('reminders_end') ?? 21,
      everyHours: prefs.getInt('reminders_every') ?? 2,
    );
    _loadDay();
    notifyListeners();
  }

  /// Switches to a fresh list if the date changed. Returns true if it did.
  bool refreshDay() {
    final key = dayKey(DateTime.now());
    if (key == _day) return false;
    _day = key;
    _loadDay();
    notifyListeners();
    return true;
  }

  void add(int ml) {
    refreshDay();
    entries.insert(0, WaterEntry(ml, DateTime.now()));
    _save();
    notifyListeners();
  }

  /// Removes [entry] and returns its index so it can be restored.
  int remove(WaterEntry entry) {
    final index = entries.indexOf(entry);
    if (index < 0) return index;
    entries.removeAt(index);
    _save();
    notifyListeners();
    return index;
  }

  void restore(int index, WaterEntry entry) {
    entries.insert(index.clamp(0, entries.length), entry);
    _save();
    notifyListeners();
  }

  void setGoal(int value) {
    goal = value;
    _prefs?.setInt('goal', value);
    _prefs?.setInt('goal_$_day', value);
    notifyListeners();
  }

  void setCup(int index, int ml) {
    cups[index] = ml;
    _prefs?.setStringList('cups', cups.map((c) => '$c').toList());
    notifyListeners();
  }

  void setReminders(ReminderSettings value) {
    reminders = value;
    _prefs
      ?..setBool('reminders', value.enabled)
      ..setInt('reminders_start', value.startHour)
      ..setInt('reminders_end', value.endHour)
      ..setInt('reminders_every', value.everyHours);
    notifyListeners();
  }

  /// The last [days] days, oldest first and today last.
  List<DayTotal> recentDays(int days) {
    final now = DateTime.now();
    return [
      for (var i = days - 1; i >= 0; i--)
        _dayTotal(DateTime(now.year, now.month, now.day - i), isToday: i == 0),
    ];
  }

  /// Days in a row the goal was met, up to today. Today only counts once
  /// it's met; until then the streak from yesterday still stands.
  int get streak {
    final now = DateTime.now();
    var count = 0;
    for (var i = 0; i < 366; i++) {
      final day = _dayTotal(
        DateTime(now.year, now.month, now.day - i),
        isToday: i == 0,
      );
      if (day.met) {
        count++;
      } else if (i > 0) {
        break;
      }
    }
    return count;
  }

  DayTotal _dayTotal(DateTime day, {required bool isToday}) {
    if (isToday) return DayTotal(day, total, goal);
    final key = dayKey(day);
    final raw = _prefs?.getString('entries_$key');
    final sum = raw == null
        ? 0
        : (jsonDecode(raw) as List).fold<int>(
            0,
            (s, e) => s + ((e as Map<String, dynamic>)['a'] as int),
          );
    return DayTotal(day, sum, _prefs?.getInt('goal_$key') ?? goal);
  }

  void _loadDay() {
    final raw = _prefs?.getString('entries_$_day');
    entries = raw == null
        ? []
        : (jsonDecode(raw) as List)
              .map((e) => WaterEntry.fromJson(e as Map<String, dynamic>))
              .toList();
  }

  void _save() {
    _prefs
      ?..setString(
        'entries_$_day',
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      )
      ..setInt('goal_$_day', goal);
  }

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
