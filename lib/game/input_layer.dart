import 'package:flutter/widgets.dart';

import 'rescue_game.dart';

/// The single gameplay input arbiter.
///
/// It listens to raw pointers (no gesture-arena competition) and classifies
/// each finished pointer as either a tap or a swipe:
///  * moved less than the minimum swipe distance → tap at the down point
///    (deploy a chute, else hit a hazard);
///  * otherwise → swipe → wind gust. A swipe never deploys chutes.
///
/// Flutter overlays (pause button, menus) sit above this widget, so they always
/// win. The game ignores input unless it is playing.
class GameInputLayer extends StatefulWidget {
  const GameInputLayer({super.key, required this.game, required this.child});

  final RescueGame game;
  final Widget child;

  @override
  State<GameInputLayer> createState() => _GameInputLayerState();
}

class _Track {
  _Track(this.start, this.time);
  final Offset start;
  final Duration time;
  Offset last = Offset.zero;
}

class _GameInputLayerState extends State<GameInputLayer> {
  final Map<int, _Track> _pointers = {};

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = _Track(e.localPosition, e.timeStamp)
      ..last = e.localPosition;
  }

  void _move(PointerMoveEvent e) {
    _pointers[e.pointer]?.last = e.localPosition;
  }

  void _up(PointerUpEvent e) {
    final track = _pointers.remove(e.pointer);
    if (track == null) return;
    final game = widget.game;
    final start = game.screenToWorld(track.start);
    final end = game.screenToWorld(e.localPosition);
    final seconds = (e.timeStamp - track.time).inMicroseconds / 1e6;
    if ((end - start).length < game.config.wind.minSwipeDistance) {
      game.handleTap(start);
    } else {
      game.handleSwipe(start, end, seconds);
    }
  }

  void _cancel(PointerCancelEvent e) => _pointers.remove(e.pointer);

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _cancel,
    child: widget.child,
  );
}
