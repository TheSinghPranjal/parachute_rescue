import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

typedef DoodlePaint = void Function(Canvas canvas, Size size, double t);

/// Repaints a canvas drawing every frame with elapsed seconds [t]. Used to
/// show real game art (person, chute, boat, fish…) in menus and tutorials.
///
/// Only this widget's painter repaints — no widget rebuilds per frame.
class AnimatedDoodle extends StatefulWidget {
  const AnimatedDoodle({super.key, required this.paint, this.animate = true});

  final DoodlePaint paint;
  final bool animate;

  @override
  State<AnimatedDoodle> createState() => _AnimatedDoodleState();
}

class _AnimatedDoodleState extends State<AnimatedDoodle>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    });
    if (widget.animate) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _Painter(widget.paint, _time),
      size: Size.infinite,
    ),
  );
}

class _Painter extends CustomPainter {
  _Painter(this.draw, this.time) : super(repaint: time);

  final DoodlePaint draw;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    draw(canvas, size, time.value);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Painter old) => old.draw != draw;
}
