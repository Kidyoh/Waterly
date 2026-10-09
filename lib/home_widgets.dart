import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Asks the Android home screen widgets to redraw (see MainActivity.kt).
abstract final class HomeWidgets {
  static const _channel = MethodChannel('waterly/widget');
  static Timer? _pending;

  /// Redraws shortly after a burst of changes, once storage has the
  /// latest values.
  static void refresh() {
    if (!Platform.isAndroid) return;
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 400), () {
      _channel.invokeMethod<void>('refresh').catchError((_) {});
    });
  }
}
