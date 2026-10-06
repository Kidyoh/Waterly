import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'water_sim.dart';

/// How a piece of text is drawn: in air, or as one of the underwater layers.
enum Tone { normal, under, pink, cyan }

/// Caches laid-out text so it isn't rebuilt every frame.
class TextCache {
  final _painters = <String, TextPainter>{};

  /// Call once at the start of a frame, before any [get].
  void beginFrame() {
    if (_painters.length < 48) return;
    for (final p in _painters.values) {
      p.dispose();
    }
    _painters.clear();
  }

  TextPainter get(String key, TextSpan Function() build, double maxWidth) =>
      _painters[key] ??= TextPainter(
        text: build(),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

  void dispose() {
    for (final p in _painters.values) {
      p.dispose();
    }
    _painters.clear();
  }
}

/// Paints the whole water scene. The header and percentage are painted here
/// too, so the parts below the surface can be refracted by the water.
class WaterPainter extends CustomPainter {
  WaterPainter(this.sim, this.cache, {this.showText = true})
    : super(repaint: sim);

  final WaterSim sim;
  final TextCache cache;

  /// False for a bare water background (onboarding).
  final bool showText;

  static const _white = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    if (sim.size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final t = sim.time;
    cache.beginFrame();

    _paintBackground(canvas, size);
    _paintRays(canvas, size, t);

    // The surface as a polyline, and the regions below (water) and above (air).
    final pts = <Offset>[
      for (var x = -12.0; x <= w + 12; x += 6)
        Offset(x, sim.surfaceY(x).clamp(-12.0, h + 12)),
    ];
    final water = Path()
      ..addPolygon([...pts, Offset(w + 12, h + 12), Offset(-12, h + 12)], true);
    final air = Path()
      ..addPolygon([...pts, Offset(w + 12, -12), Offset(-12, -12)], true);
    final waterTop = pts.map((p) => p.dy).reduce(math.min);

    if (!showText) {
      _paintWater(canvas, size, pts, water);
      _paintBubbles(canvas, water);
      return;
    }

    // Header text.
    final fs = (w * 0.083).clamp(24.0, 40.0);
    final maxWidth = w - 48;
    final shown = formatMl(sim.shownMl.round());
    final goal = formatMl(sim.goal);
    TextPainter header(Tone tone) => cache.get(
      'hdr|$tone|$shown|$goal|$fs|$maxWidth',
      () => _headerSpan(tone, fs, shown, goal),
      maxWidth,
    );
    final headerOffset = Offset(24, sim.padding.top + 70);
    final headerBottom = headerOffset.dy + header(Tone.normal).height;

    // Percentage, riding along with the water level.
    final pct = sim.percent;
    final pfs = (w * 0.24).clamp(64.0, 120.0);
    TextPainter percent(Tone tone) => cache.get(
      'pct|$tone|$pct|$pfs',
      () => TextSpan(
        text: '$pct%',
        style: manrope(
          pfs,
          weight: FontWeight.w500,
          color: _toneColor(tone, true),
          letterSpacing: -pfs * 0.04,
          height: 1,
        ),
      ),
      w,
    );
    final pctHeight = percent(Tone.normal).height;
    final lift = ui.lerpDouble(-0.08, 0.05, sim.level.clamp(0.0, 1.0))!;
    final minTop = headerBottom + 6;
    final maxTop = math.max(minTop, sim.sheetTop - 72 - pctHeight);
    final pctOffset = Offset(
      22,
      (sim.baseY + lift * h).clamp(minTop, maxTop).toDouble(),
    );

    // Text above the water.
    _paintAbove(canvas, header(Tone.normal), headerOffset, air, waterTop);
    _paintAbove(canvas, percent(Tone.normal), pctOffset, air, waterTop);

    _paintWater(canvas, size, pts, water);

    // Text below the water, wobbling.
    _paintBelow(canvas, header, headerOffset, water, waterTop, t);
    _paintBelow(canvas, percent, pctOffset, water, waterTop, t);

    _paintBubbles(canvas, water);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [WaterColors.bgTop, WaterColors.bgMid, WaterColors.bgBottom],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  /// Soft diagonal light shafts, slowly breathing.
  void _paintRays(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 4; i++) {
      final a = 0.045 + 0.03 * math.sin(t * 0.35 + i * 1.9);
      final bw = w * (0.10 + 0.07 * (i % 3));
      canvas.save();
      canvas.translate(w * (0.15 + 0.32 * i), -h * 0.05);
      canvas.rotate(0.5);
      final rect = Rect.fromLTWH(-bw / 2, 0, bw, h * 1.4);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            [
              _white.withValues(alpha: a),
              _white.withValues(alpha: a * 0.4),
              _white.withValues(alpha: 0),
            ],
            [0, 0.45, 1],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
      canvas.restore();
    }
  }

  void _paintWater(Canvas canvas, Size size, List<Offset> pts, Path water) {
    // Shade along gravity, so the gradient tilts with the surface.
    final down = Offset(-math.sin(sim.angle), math.cos(sim.angle));
    final p0 = Offset(size.width / 2, sim.baseY) - down * 20;
    final depth = (size.height - sim.baseY + 80).clamp(200.0, 4000.0);
    canvas.drawPath(
      water,
      Paint()
        ..shader = ui.Gradient.linear(
          p0,
          p0 + down * depth,
          [
            WaterColors.waterSurface.withValues(alpha: 0.95),
            WaterColors.waterBody.withValues(alpha: 0.82),
            WaterColors.waterBody.withValues(alpha: 0.72),
            WaterColors.waterDeep.withValues(alpha: 0.9),
          ],
          [0, 0.08, 0.4, 1],
        ),
    );

    final surface = Path()..addPolygon(pts, false);
    canvas.save();
    canvas.clipPath(water);
    // Glow just under the surface.
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..color = const Color(0xFF8FE3E8).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Crisp crest.
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _white.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  void _paintAbove(
    Canvas canvas,
    TextPainter tp,
    Offset offset,
    Path air,
    double waterTop,
  ) {
    if (offset.dy + tp.height < waterTop) {
      tp.paint(canvas, offset);
      return;
    }
    canvas.save();
    canvas.clipPath(air);
    tp.paint(canvas, offset);
    canvas.restore();
  }

  /// Paints the submerged part of a text in thin horizontal strips, each
  /// shifted by a moving wave, with a slight colour fringe — like looking
  /// at it through water.
  void _paintBelow(
    Canvas canvas,
    TextPainter Function(Tone) text,
    Offset offset,
    Path water,
    double waterTop,
    double t,
  ) {
    final under = text(Tone.under);
    final rect = offset & under.size;
    if (rect.bottom < waterTop) return;
    final pink = text(Tone.pink);
    final cyan = text(Tone.cyan);

    const strip = 1.5;
    canvas.save();
    canvas.clipPath(water);
    for (
      var y = math.max(rect.top - 4, waterTop - strip);
      y < rect.bottom + 4;
      y += strip
    ) {
      final dx =
          math.sin(y * 0.06 + t * 2.4) * 3.5 +
          math.sin(y * 0.13 - t * 1.5) * 1.2;
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(rect.left - 24, y, rect.right + 24, y + strip + 0.5),
      );
      pink.paint(canvas, offset.translate(dx + 1.3, 0));
      cyan.paint(canvas, offset.translate(dx - 1.3, 0));
      under.paint(canvas, offset.translate(dx, 0));
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintBubbles(Canvas canvas, Path water) {
    if (sim.bubbles.isEmpty) return;
    final fill = Paint()..color = _white.withValues(alpha: 0.10);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _white.withValues(alpha: 0.5);
    final shine = Paint()..color = _white.withValues(alpha: 0.7);
    canvas.save();
    canvas.clipPath(water);
    for (final b in sim.bubbles) {
      final c = Offset(b.x, b.y);
      canvas.drawCircle(c, b.radius, fill);
      canvas.drawCircle(c, b.radius, ring);
      canvas.drawCircle(
        c.translate(-b.radius * 0.35, -b.radius * 0.35),
        b.radius * 0.28,
        shine,
      );
    }
    canvas.restore();
  }

  TextSpan _headerSpan(Tone tone, double fs, String shown, String goal) {
    TextStyle style(bool bright, FontWeight weight) => manrope(
      fs,
      weight: weight,
      color: _toneColor(tone, bright),
      letterSpacing: -fs * 0.015,
      height: 1.12,
    );
    return TextSpan(
      children: [
        TextSpan(text: 'Water\n', style: style(true, FontWeight.w600)),
        TextSpan(text: 'today: ', style: style(false, FontWeight.w500)),
        TextSpan(text: shown, style: style(true, FontWeight.w600)),
        TextSpan(text: ' of $goal ml', style: style(false, FontWeight.w500)),
      ],
    );
  }

  static Color _toneColor(Tone tone, bool bright) => switch (tone) {
    Tone.normal => bright ? _white : _white.withValues(alpha: 0.42),
    Tone.under =>
      bright
          ? const Color(0xFFF4FEFF)
          : const Color(0xFFD5F6F8).withValues(alpha: 0.6),
    Tone.pink => const Color(
      0xFFFF8FC8,
    ).withValues(alpha: bright ? 0.55 : 0.25),
    Tone.cyan => const Color(
      0xFF6CF6FF,
    ).withValues(alpha: bright ? 0.55 : 0.25),
  };

  @override
  bool shouldRepaint(WaterPainter oldDelegate) =>
      oldDelegate.sim != sim ||
      oldDelegate.cache != cache ||
      oldDelegate.showText != showText;
}
