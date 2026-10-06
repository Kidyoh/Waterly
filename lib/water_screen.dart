import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'reminders.dart';
import 'theme.dart';
import 'water_painter.dart';
import 'water_sim.dart';
import 'water_store.dart';
import 'widgets/add_controls.dart';
import 'widgets/amount_sheet.dart';
import 'widgets/settings_sheet.dart';
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

  /// Shows the "Goal reached" pill for a moment.
  bool _goalPill = false;
  Timer? _goalPillTimer;

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
    _store.load().then((_) {
      _sim.setTotals(_store.total, _store.goal);
      _reschedule();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accel?.cancel();
    _goalPillTimer?.cancel();
    _ticker.dispose();
    _sim.dispose();
    _textCache.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_store.refreshDay()) _sim.setTotals(_store.total, _store.goal);
    _reschedule();
  }

  /// Rebuilds the reminder plan, which depends on today's total.
  void _reschedule() {
    unawaited(Reminders.instance.reschedule(_store).catchError((_) {}));
  }

  /// Applies a change to the totals or goal everywhere it shows.
  void _totalsChanged() {
    _sim.setTotals(_store.total, _store.goal);
    _reschedule();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _sim.step(dt);
  }

  void _add(int ml) {
    final before = _store.total;
    HapticFeedback.mediumImpact();
    _store.add(ml);
    _sim.pourIn(_store.total, _store.goal);
    _reschedule();
    if (before < _store.goal && _store.total >= _store.goal) _celebrate();
  }

  void _celebrate() {
    _sim.celebrate();
    HapticFeedback.heavyImpact();
    Future<void>.delayed(
      const Duration(milliseconds: 180),
      HapticFeedback.mediumImpact,
    );
    setState(() => _goalPill = true);
    _goalPillTimer?.cancel();
    _goalPillTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _goalPill = false);
    });
  }

  void _delete(WaterEntry entry) {
    final index = _store.remove(entry);
    _totalsChanged();
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
              _totalsChanged();
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
      hint: 'Tip: long-press + to set your own cup sizes.',
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
    _totalsChanged();
  }

  Future<void> _editCup(int index) async {
    HapticFeedback.selectionClick();
    final ml = await showAmountSheet(
      context,
      title: 'Cup size',
      initial: _store.cups[index],
      min: 50,
      max: 1500,
      step: 10,
      presets: const [150, 200, 250, 330, 500, 750],
      action: 'Save cup',
    );
    if (ml != null) _store.setCup(index, ml);
  }

  Future<void> _setReminders(ReminderSettings value) async {
    final turningOn = value.enabled && !_store.reminders.enabled;
    if (turningOn && !await Reminders.instance.requestPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: WaterColors.ink,
          content: Text(
            'Allow notifications for Waterly in your phone’s settings '
            'to get reminders.',
            style: manrope(14, color: Colors.white),
          ),
        ),
      );
      return;
    }
    _store.setReminders(value);
    _reschedule();
  }

  void _openSettings() {
    showSettingsSheet(
      context,
      store: _store,
      onEditGoal: _editGoal,
      onEditCup: _editCup,
      onRemindersChanged: _setReminders,
    );
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
                child: _SettingsButton(onTap: _openSettings),
              ),
              Positioned(
                right: 20,
                top: padding.top + 18,
                child: IgnorePointer(
                  child: AnimatedSlide(
                    offset: _goalPill ? Offset.zero : const Offset(0, -0.6),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: _goalPill ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const _GoalPill(),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: sheetTop - 62,
                child: ListenableBuilder(
                  listenable: _store,
                  builder: (context, _) => AddControls(
                    cups: _store.cups,
                    onAdd: _add,
                    onEditCup: _editCup,
                    onCustom: _custom,
                  ),
                ),
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

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Settings',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: WaterColors.backButton,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _GoalPill extends StatelessWidget {
  const _GoalPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: WaterColors.lime,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: WaterColors.lime.withValues(alpha: 0.4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.celebration_rounded,
            size: 18,
            color: WaterColors.ink,
          ),
          const SizedBox(width: 8),
          Text('Goal reached', style: manrope(14, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}
