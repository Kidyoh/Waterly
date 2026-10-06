import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class Bubble {
  Bubble(this.x, this.y, this.radius, this.speed, this.phase);

  double x;
  double y;
  final double radius;
  final double speed;
  final double phase;
}

/// A local disturbance on the surface, e.g. where the stream hits the water.
class Ripple {
  Ripple(this.x, this.strength);

  final double x;
  final double strength;
  double age = 0;
}

/// Physics for the water: fill level, tilt against gravity, sloshing waves,
/// pouring and bubbles. Ticked every frame by the screen and
/// read by the painter.
class WaterSim extends ChangeNotifier {
  static const pourDuration = 0.9;

  final _rng = math.Random();

  // Layout, set by the screen on every build.
  Size size = Size.zero;
  EdgeInsets padding = EdgeInsets.zero;
  double sheetTop = 0;

  double time = 0;

  /// Fill fraction (0 = empty, 1 = goal reached), animated by a spring.
  double level = 0;
  double _levelVel = 0;
  double _targetLevel = 0;

  /// Angle of the surface relative to the screen, in radians. Follows the
  /// phone's roll with an underdamped spring so the water sloshes.
  double angle = 0;
  double _angleVel = 0;
  double _targetAngle = 0;

  /// Extra wave energy from motion and pouring; decays over time.
  double slosh = 0;

  /// Millilitres shown in the header, counting towards the real total.
  double shownMl = 0;
  double _targetMl = 0;
  int goal = 2000;

  /// Seconds left of the current pour.
  double pour = 0;
  double pourX = 0;

  final bubbles = <Bubble>[];
  final ripples = <Ripple>[];

  double _bubbleClock = 0;
  double _rippleClock = 0;
  double _ambientClock = 0;

  void layout(Size size, EdgeInsets padding, double sheetTop) {
    this.size = size;
    this.padding = padding;
    this.sheetTop = sheetTop;
  }

  /// Y of the surface at 100% and at 0%.
  double get levelTopY => padding.top + 150;
  double get levelBottomY => sheetTop - 4;

  /// Y of the untilted, calm surface for the current level.
  double get baseY =>
      lerpDouble(levelBottomY, levelTopY, level.clamp(-0.05, 1.08))!;

  int get percent {
    if (goal <= 0) return 0;
    return (shownMl / goal * 100).floor().clamp(0, 100);
  }

  /// Y of the water surface at screen x, including tilt, waves and ripples.
  double surfaceY(double x) {
    final w = size.width;
    if (w == 0) return 0;
    final k = 2 * math.pi / w;
    final amp = 3.5 + slosh * 16;
    var y =
        math.sin(x * k * 1.2 + time * 1.6) * 0.55 +
        math.sin(x * k * 2.7 - time * 2.3) * 0.30 +
        math.sin(x * k * 5.1 + time * 3.7) * 0.15;
    y *= amp;
    for (final r in ripples) {
      final d = (x - r.x).abs();
      y +=
          r.strength *
          math.exp(-r.age * 1.8) *
          math.sin(d * 0.05 - r.age * 9) *
          math.exp(-d / 160);
    }
    return baseY + math.tan(angle) * (x - w / 2) + y;
  }

  /// Sets totals without pouring (initial load, deletes, goal changes).
  void setTotals(int totalMl, int goal) {
    this.goal = goal;
    _targetMl = totalMl.toDouble();
    _targetLevel = goal <= 0 ? 0 : math.min(totalMl / goal, 1.08);
  }

  /// Moves the water to [fraction] of the screen without changing totals.
  void setLevel(double fraction) => _targetLevel = fraction;

  /// Pours water in: bubbles and ripples, then the level rises.
  void pourIn(int totalMl, int goal) {
    setTotals(totalMl, goal);
    pour = pourDuration;
    pourX = size.width * (0.26 + _rng.nextDouble() * 0.12);
    slosh = math.min(slosh + 0.25, 1.2);
    ripples.add(Ripple(pourX, 8));
  }

  /// Feeds an accelerometer reading (device axes, m/s², gravity reaction).
  void setGravity(double ax, double ay) {
    // Phone lying flat: the roll is undefined, keep the last one.
    if (math.sqrt(ax * ax + ay * ay) < 2.5) return;
    _targetAngle = math.atan2(ax, ay).clamp(-1.25, 1.25);
  }

  void step(double dt) {
    if (size.isEmpty) return;
    dt = dt.clamp(0.0, 1 / 20);
    time += dt;

    // Level spring.
    _levelVel += ((_targetLevel - level) * 14 - _levelVel * 5) * dt;
    level += _levelVel * dt;

    // Tilt spring, loosely damped so it overshoots like real water.
    final angleAcc = (_targetAngle - angle) * 26 - _angleVel * 2.6;
    _angleVel += angleAcc * dt;
    angle += _angleVel * dt;

    slosh += (angleAcc.abs() * 0.06 + _levelVel.abs() * 0.8) * dt;
    slosh = (slosh * math.exp(-1.4 * dt)).clamp(0.0, 1.2);

    // Header counter.
    shownMl += (_targetMl - shownMl) * (1 - math.exp(-5 * dt));
    if ((_targetMl - shownMl).abs() < 0.5) shownMl = _targetMl;

    // Pouring: bubbles and ripples where the water lands.
    if (pour > 0) {
      pour = math.max(0, pour - dt);
      _bubbleClock += dt;
      while (_bubbleClock > 1 / 28) {
        _bubbleClock -= 1 / 28;
        _spawnBubble(pourX + (_rng.nextDouble() - 0.5) * 40, 10, 110);
      }
      _rippleClock += dt;
      if (_rippleClock > 0.18) {
        _rippleClock = 0;
        ripples.add(Ripple(pourX, 5));
      }
    }

    // A lazy bubble now and then.
    if (level > 0.06) {
      _ambientClock += dt;
      if (_ambientClock > 0.9) {
        _ambientClock = 0;
        _spawnBubble(_rng.nextDouble() * size.width, 60, 400);
      }
    }

    for (final r in ripples) {
      r.age += dt;
    }
    ripples.removeWhere((r) => r.age > 3);

    for (final b in bubbles) {
      b.y -= b.speed * dt;
      b.x += math.sin(time * 3 + b.phase) * 10 * dt;
    }
    bubbles.removeWhere(
      (b) => b.y - b.radius <= surfaceY(b.x) || b.y > size.height,
    );

    notifyListeners();
  }

  void _spawnBubble(double x, double minDepth, double maxDepth) {
    final surface = surfaceY(x);
    final top = surface + minDepth;
    final bottom = math.min(surface + maxDepth, sheetTop - 10);
    if (bottom <= top) return;
    bubbles.add(
      Bubble(
        x,
        top + _rng.nextDouble() * (bottom - top),
        1.5 + _rng.nextDouble() * 4.5,
        30 + _rng.nextDouble() * 50,
        _rng.nextDouble() * math.pi * 2,
      ),
    );
  }
}
