import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'theme.dart';
import 'water_painter.dart';
import 'water_sim.dart';
import 'water_store.dart';
import 'widgets/add_controls.dart';
import 'widgets/amount_sheet.dart';
import 'widgets/today_sheet.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key, this.store, this.useSensors = true});

  /// Injected in tests; a fresh store otherwise.
  final WaterStore? store;
  final bool useSensors;

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final WaterStore _store = widget.store ?? WaterStore();
  final _sim = WaterSim();
  final _textCache = TextCache();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  StreamSubscription<AccelerometerEvent>? _accel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick)..start();
    if (widget.useSensors) {
      _accel =
          accelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          ).listen(
            (e) => _sim.setGravity(e.x, e.y),
            // No accelerometer (desktop, some emulators): the water just stays level.
            onError: (_) {},
          );
    }
    _store.load().then((_) => _sim.setTotals(_store.total, _store.goal));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accel?.cancel();
    _ticker.dispose();
    _sim.dispose();
    _textCache.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _store.refreshDay()) {
      _sim.setTotals(_store.total, _store.goal);
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _sim.step(dt);
  }

  void _add(int ml) {
    HapticFeedback.mediumImpact();
    _store.add(ml);
    _sim.pourIn(_store.total, _store.goal);
  }

  void _delete(WaterEntry entry) {
    final index = _store.remove(entry);
    _sim.setTotals(_store.total, _store.goal);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: WaterColors.ink,
          content: Text(
            'Removed ${entry.amount} ml',
            style: manrope(14, color: Colors.white),
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: WaterColors.lime,
            onPressed: () {
              _store.restore(index, entry);
              _sim.setTotals(_store.total, _store.goal);
            },
          ),
        ),
      );
  }

  Future<void> _custom() async {
    final ml = await showAmountSheet(
      context,
      title: 'Add water',
      initial: 300,
      min: 50,
      max: 1500,
      step: 50,
      presets: const [100, 200, 300, 500, 750, 1000],
      action: 'Add',
    );
    if (ml != null && mounted) _add(ml);
  }

  Future<void> _editGoal() async {
    final goal = await showAmountSheet(
      context,
      title: 'Daily goal',
      initial: _store.goal,
      min: 500,
      max: 5000,
      step: 100,
      presets: const [1500, 2000, 2500, 3000, 3500],
      action: 'Save goal',
    );
    if (goal == null) return;
    _store.setGoal(goal);
    _sim.setTotals(_store.total, _store.goal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaterColors.bgTop,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final padding = MediaQuery.paddingOf(context);
          final sheetFraction = math
              .max(0.25, 220 / size.height)
              .clamp(0.0, 0.5);
          final sheetTop = size.height * (1 - sheetFraction);
          _sim.layout(size, padding, sheetTop);

          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: WaterPainter(_sim, _textCache)),
                ),
              ),
              // Tap the header to change the daily goal.
              Positioned(
                left: 16,
                right: 16,
                top: padding.top + 64,
                height: 130,
                child: Semantics(
                  button: true,
                  label: 'Change daily goal',
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _editGoal,
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: padding.top + 12,
                child: _BackButton(onTap: () => Navigator.maybePop(context)),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: sheetTop - 62,
                child: AddControls(onAdd: _add, onCustom: _custom),
              ),
              DraggableScrollableSheet(
                initialChildSize: sheetFraction,
                minChildSize: sheetFraction,
                maxChildSize: 0.85,
                snap: true,
                builder: (context, controller) => TodaySheet(
                  store: _store,
                  controller: controller,
                  onDelete: _delete,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: WaterColors.backButton,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
