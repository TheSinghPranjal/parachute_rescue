/// Continuous (swept) landing tests, independent of Flame.
library;

/// A deck's horizontal span at the start and end of a substep.
class DeckSweep {
  const DeckSweep({
    required this.deckY,
    required this.prevCenterX,
    required this.centerX,
    required this.halfWidth,
  });

  final double deckY;
  final double prevCenterX;
  final double centerX;
  final double halfWidth;
}

/// Returns the fraction t∈[0,1] of the substep at which the feet crossed the
/// deck plane while overlapping the deck horizontally, or null otherwise.
///
/// Both the person's x and the deck's x are interpolated to the crossing
/// instant, so a moving deck is evaluated where it actually was.
double? sweptDeckHit({
  required double prevFeetY,
  required double feetY,
  required double prevX,
  required double x,
  required double footprintHalfWidth,
  required DeckSweep deck,
}) {
  // Must be descending through the plane.
  if (!(prevFeetY <= deck.deckY && feetY > deck.deckY)) return null;
  final span = feetY - prevFeetY;
  final t = span <= 0 ? 0.0 : (deck.deckY - prevFeetY) / span;
  final px = prevX + (x - prevX) * t;
  final dx = deck.prevCenterX + (deck.centerX - deck.prevCenterX) * t;
  final overlap = (px - dx).abs() <= deck.halfWidth + footprintHalfWidth;
  return overlap ? t : null;
}

/// True when the feet crossed the waterline/ground this substep.
bool crossedGround({
  required double prevFeetY,
  required double feetY,
  required double groundY,
}) => prevFeetY < groundY && feetY >= groundY;
