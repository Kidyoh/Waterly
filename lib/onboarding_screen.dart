import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import 'water_painter.dart';
import 'water_screen.dart';
import 'water_sim.dart';
import 'water_store.dart';

/// Three pages over live water that rises as you swipe through them:
/// what the app is, the tilting water, and picking a daily goal.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.useSensors = true});

  final bool useSensors;

  static const doneKey = 'onboarded';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _pageLevels = [0.16, 0.32, 0.46];

  final _pages = PageController();
  final _sim = WaterSim();
  final _textCache = TextCache();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  StreamSubscription<AccelerometerEvent>? _accel;

  int _page = 0;
  int _goal = WaterStore.defaultGoal;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    if (widget.useSensors) {
      _accel = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen((e) => _sim.setGravity(e.x, e.y), onError: (_) {});
    }
    _sim.setLevel(_pageLevels[0]);
    _pages.addListener(_onScroll);
  }

  @override
  void dispose() {
    _accel?.cancel();
    _ticker.dispose();
    _pages.dispose();
    _sim.dispose();
    _textCache.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _sim.step(dt);
  }

  /// The water follows the swipe, between the levels of the two pages.
  void _onScroll() {
    if (_finishing || !_pages.hasClients) return;
    final p = (_pages.page ?? 0).clamp(0.0, _pageLevels.length - 1.0);
    final i = p.floor().clamp(0, _pageLevels.length - 2);
    final f = p - i;
    _sim.setLevel(_pageLevels[i] + (_pageLevels[i + 1] - _pageLevels[i]) * f);
  }

  void _next() {
    if (_page < 2) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    HapticFeedback.mediumImpact();
    // One last big pour before handing over to the app.
    _sim.pourIn(0, 1);
    _sim.setLevel(1.1);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('goal', _goal);
    await prefs.setBool(OnboardingScreen.doneKey, true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => WaterScreen(useSensors: widget.useSensors),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaterColors.bgTop,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = MediaQuery.paddingOf(context);
          _sim.layout(constraints.biggest, padding, constraints.maxHeight);
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: WaterPainter(_sim, _textCache, showText: false),
                  ),
                ),
              ),
              SafeArea(
                child: AnimatedOpacity(
                  opacity: _finishing ? 0 : 1,
                  duration: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      _TopBar(
                        showSkip: _page < 2,
                        onSkip: () => _pages.animateToPage(
                          2,
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeInOutCubic,
                        ),
                      ),
                      Expanded(
                        child: PageView(
                          controller: _pages,
                          onPageChanged: (i) {
                            HapticFeedback.selectionClick();
                            setState(() => _page = i);
                          },
                          children: [
                            const _Page(
                              step: '01',
                              title: 'Your screen\nis the glass.',
                              body:
                                  'Every drink you log pours in. '
                                  'Watch it rise towards your daily goal.',
                              extra: _BobbingDrop(),
                            ),
                            const _Page(
                              step: '02',
                              title: 'Tilt it.\nIt’s real water.',
                              body:
                                  'The water follows gravity. '
                                  'Tip your phone and watch it slosh.',
                              extra: _TiltHint(),
                            ),
                            _Page(
                              step: '03',
                              title: 'How much\na day?',
                              body:
                                  'Around 2 litres suits most people. '
                                  'You can change it any time.',
                              extra: _GoalPicker(
                                goal: _goal,
                                onChanged: (g) => setState(() => _goal = g),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                        child: Row(
                          children: [
                            _Dots(count: 3, index: _page),
                            const Spacer(),
                            _PillButton(
                              label: _page < 2 ? 'Next' : 'Get started',
                              onTap: _next,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: WaterColors.lime,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Waterly',
            style: manrope(17, weight: FontWeight.w600, color: Colors.white),
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: showSkip ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: TextButton(
              onPressed: showSkip ? onSkip : null,
              child: Text(
                'Skip',
                style: manrope(
                  15,
                  weight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.step,
    required this.title,
    required this.body,
    this.extra,
  });

  final String step;
  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: manrope(
              14,
              weight: FontWeight.w600,
              color: WaterColors.lime,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: manrope(
              (w * 0.115).clamp(32.0, 52.0),
              weight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -1.2,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              body,
              style: manrope(
                16,
                weight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.45,
              ),
            ),
          ),
          if (extra != null)
            // Shrinks on short screens instead of overflowing.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: extra),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The app's drop, floating gently.
class _BobbingDrop extends StatefulWidget {
  const _BobbingDrop();

  @override
  State<_BobbingDrop> createState() => _BobbingDropState();
}

class _BobbingDropState extends State<_BobbingDrop>
    with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        final t = _bob.value * math.pi * 2;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * 8),
          child: Transform.rotate(angle: math.sin(t + 1) * 0.05, child: child),
        );
      },
      child: Image.asset(
        'assets/icon/icon_foreground.png',
        width: 300,
        height: 300,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// A little phone that rocks side to side.
class _TiltHint extends StatefulWidget {
  const _TiltHint();

  @override
  State<_TiltHint> createState() => _TiltHintState();
}

class _TiltHintState extends State<_TiltHint>
    with SingleTickerProviderStateMixin {
  late final _rock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _rock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rock,
      builder: (context, child) => Transform.rotate(
        angle: math.sin(_rock.value * math.pi * 2) * 0.35,
        child: child,
      ),
      child: Container(
        width: 64,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 3,
          ),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          width: 18,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _GoalPicker extends StatelessWidget {
  const _GoalPicker({required this.goal, required this.onChanged});

  final int goal;
  final ValueChanged<int> onChanged;

  static const _step = 250;
  static const _min = 500;
  static const _max = 5000;

  void _change(int delta) {
    final next = (goal + delta).clamp(_min, _max);
    if (next == goal) return;
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(icon: Icons.remove_rounded, onTap: () => _change(-_step)),
        SizedBox(
          width: 190,
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.9, end: 1.0).animate(a),
                    child: child,
                  ),
                ),
                child: Text(
                  formatMl(goal),
                  key: ValueKey(goal),
                  style: manrope(
                    54,
                    weight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -2,
                  ),
                ),
              ),
              Text(
                'ml per day',
                style: manrope(
                  14,
                  weight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        _RoundButton(icon: Icons.add_rounded, onTap: () => _change(_step)),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WaterColors.chip.withValues(alpha: 0.75),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(right: 6),
            width: i == index ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index
                  ? WaterColors.lime
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WaterColors.lime,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: manrope(16, weight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: WaterColors.ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
