import 'package:flutter/material.dart';

import '../theme.dart';

/// "+ 150 ml", "+ 250 ml" and the lime "Custom" pill.
class AddControls extends StatelessWidget {
  const AddControls({super.key, required this.onAdd, required this.onCustom});

  final ValueChanged<int> onAdd;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickAdd(ml: 150, onTap: () => onAdd(150)),
        const SizedBox(width: 14),
        _QuickAdd(ml: 250, onTap: () => onAdd(250)),
        const Spacer(),
        _Pressable(
          onTap: onCustom,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WaterColors.lime,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: WaterColors.lime.withValues(alpha: 0.35),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Text('Custom', style: manrope(14, weight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.ml, required this.onTap});

  final int ml;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: WaterColors.chip.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 9),
          Text(
            '$ml ml',
            style: manrope(
              12,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shrinks slightly while pressed.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool down) => setState(() => _down = down);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
