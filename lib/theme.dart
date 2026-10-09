import 'package:flutter/painting.dart';

/// Colours and type taken from the reference design.
abstract final class WaterColors {
  static const bgTop = Color(0xFF0B3646);
  static const bgMid = Color(0xFF125466);
  static const bgBottom = Color(0xFF1B6F7F);

  static const waterSurface = Color(0xFF5BC3CC);
  static const waterBody = Color(0xFF2B95A3);
  static const waterDeep = Color(0xFF16606F);

  static const sheet = Color(0xFFE9DDEB);
  static const sheetBottom = Color(0xFFDCCDE0);
  static const ink = Color(0xFF15181A);

  static const lime = Color(0xFFE4EF1C);
  static const backButton = Color(0xFF1F86A6);
  static const chip = Color(0xFF223A44);
}

/// Manrope ships as a variable font, so the weight is set on the `wght` axis.
TextStyle manrope(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = WaterColors.ink,
  double letterSpacing = 0,
  double? height,
}) => TextStyle(
  fontFamily: 'Manrope',
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation.weight(weight.value.toDouble())],
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// 1150 -> "1,150"
String formatMl(int ml) {
  final s = ml.abs().toString();
  final out = StringBuffer(ml < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
