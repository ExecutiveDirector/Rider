// lib/core/widgets/pulse_dot.dart
import 'package:flutter/material.dart';

/// A small dot that pulses outward with a soft ring — used for "online",
/// "live tracking", and "new order" indicators so those states read as
/// alive rather than static.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = widget.size * 3.2;
    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0) * 0.45,
                child: Container(
                  width: widget.size + (ringSize - widget.size) * t,
                  height: widget.size + (ringSize - widget.size) * t,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.6),
                      blurRadius: widget.size * 0.6,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
