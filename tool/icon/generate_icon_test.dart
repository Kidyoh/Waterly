// Draws the app icon PNGs. Not part of the normal test run; regenerate with:
//
//   flutter test tool/icon --update-goldens && cp tool/icon/icon_*.png assets/icon/
//   dart run flutter_launcher_icons
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterly/theme.dart';

enum _Layer { full, foreground, background, monochrome }

class _IconPainter extends CustomPainter {
  _IconPainter(this.layer);

  final _Layer layer;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas.scale(s);
    const rect = Rect.fromLTWH(0, 0, 1024, 1024);

    if (layer == _Layer.full || layer == _Layer.background) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(200, 0),
            const Offset(824, 1024),
            const [Color(0xFF0B3646), Color(0xFF13596B), Color(0xFF1E7A89)],
            const [0, 0.5, 1],
          ),
      );
      // A soft light shaft.
      canvas.save();
      canvas.translate(700, -80);
      canvas.rotate(0.5);
      canvas.drawRect(
        const Rect.fromLTWH(-110, 0, 220, 1500),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 1300), [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ])
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
      canvas.restore();
    }
    if (layer == _Layer.background) return;

    // Adaptive icons get masked to a circle, so keep the drop in the
    // safe zone there.
    if (layer != _Layer.full) {
      canvas.translate(512, 512);
      canvas.scale(0.78);
      canvas.translate(-512, -512);
    }
    canvas.translate(0, -12);

    final drop = Path()
      ..moveTo(512, 168)
      ..cubicTo(560, 262, 756, 430, 756, 600)
      ..arcTo(
        Rect.fromCircle(center: const Offset(512, 600), radius: 244),
        0,
        math.pi,
        false,
      )
      ..cubicTo(268, 430, 464, 262, 512, 168)
      ..close();

    if (layer == _Layer.monochrome) {
      canvas.drawPath(drop, Paint()..color = Colors.white);
      return;
    }

    // Glass.
    canvas.drawPath(
      drop,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    // Tilted water inside the drop.
    canvas.save();
    canvas.clipPath(drop);
    double surfaceY(double x) =>
        548 - (x - 512) * 0.2 + math.sin(x * 0.022) * 12;
    final crest = Path()..moveTo(200, surfaceY(200));
    for (var x = 204.0; x <= 824; x += 4) {
      crest.lineTo(x, surfaceY(x));
    }
    final water = Path.from(crest)
      ..lineTo(824, 900)
      ..lineTo(200, 900)
      ..close();
    canvas.drawPath(
      water,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(512, 470),
          const Offset(512, 860),
          const [Color(0xFF8FE3E8), Color(0xFF3FAFBB), Color(0xFF1F8494)],
          const [0, 0.25, 1],
        ),
    );
    // Crest.
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    // Bubbles.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(const Offset(430, 690), 26, ring);
    canvas.drawCircle(const Offset(500, 770), 15, ring);
    canvas.drawCircle(
      const Offset(604, 700),
      44,
      Paint()..color = WaterColors.lime,
    );
    canvas.restore();

    // Rim.
    canvas.drawPath(
      drop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) => false;
}

void main() {
  for (final layer in _Layer.values) {
    testWidgets('icon ${layer.name}', (tester) async {
      tester.view.physicalSize = const Size(1024, 1024);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        RepaintBoundary(
          child: CustomPaint(
            size: const Size(1024, 1024),
            painter: _IconPainter(layer),
          ),
        ),
      );
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('icon_${layer.name}.png'),
      );
    });
  }
}
