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

/// Today's intake and the daily goal, persisted on device.
///
/// Entries are stored per calendar day, so a new day starts empty.
class WaterStore extends ChangeNotifier {
  static const defaultGoal = 2000;

  SharedPreferences? _prefs;
  String _day = _dayKey(DateTime.now());

  int goal = defaultGoal;

  /// Today's entries, newest first.
  List<WaterEntry> entries = [];

  int get total => entries.fold(0, (sum, e) => sum + e.amount);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    goal = _prefs!.getInt('goal') ?? defaultGoal;
    _loadDay();
    notifyListeners();
  }

  /// Switches to a fresh list if the date changed. Returns true if it did.
  bool refreshDay() {
    final key = _dayKey(DateTime.now());
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
    notifyListeners();
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
    _prefs?.setString(
      'entries_$_day',
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
