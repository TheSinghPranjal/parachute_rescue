import 'package:flutter_test/flutter_test.dart';
import 'package:parachute_rescue/domain/landing.dart';

void main() {
  const deck = DeckSweep(
    deckY: 1000,
    prevCenterX: 300,
    centerX: 300,
    halfWidth: 75,
  );

  test('crossing a deck inside its span is a landing', () {
    final t = sweptDeckHit(
      prevFeetY: 995,
      feetY: 1003,
      prevX: 320,
      x: 320,
      footprintHalfWidth: 14,
      deck: deck,
    );
    expect(t, isNotNull);
    expect(t, inInclusiveRange(0, 1));
  });

  test('fast fall cannot tunnel through the deck', () {
    // 400 units in one step still registers.
    final t = sweptDeckHit(
      prevFeetY: 700,
      feetY: 1100,
      prevX: 300,
      x: 300,
      footprintHalfWidth: 14,
      deck: deck,
    );
    expect(t, closeTo(0.75, 1e-9));
  });

  test('missing the deck horizontally is not a landing', () {
    expect(
      sweptDeckHit(
        prevFeetY: 995,
        feetY: 1003,
        prevX: 500,
        x: 500,
        footprintHalfWidth: 14,
        deck: deck,
      ),
      isNull,
    );
  });

  test('footprint overlap at the very edge counts', () {
    // Centre is 85 from the deck centre: deck 75 + feet 14 = 89 reach.
    expect(
      sweptDeckHit(
        prevFeetY: 995,
        feetY: 1003,
        prevX: 385,
        x: 385,
        footprintHalfWidth: 14,
        deck: deck,
      ),
      isNotNull,
    );
  });

  test('moving up through the plane is ignored', () {
    expect(
      sweptDeckHit(
        prevFeetY: 1003,
        feetY: 995,
        prevX: 300,
        x: 300,
        footprintHalfWidth: 14,
        deck: deck,
      ),
      isNull,
    );
  });

  test('the deck position at the crossing instant is used', () {
    // The deck moves from x=100 to x=400 during the step; the person stays
    // at 380. At the crossing (t≈0.9) the deck is near 370 → landing.
    const moving = DeckSweep(
      deckY: 1000,
      prevCenterX: 100,
      centerX: 400,
      halfWidth: 75,
    );
    expect(
      sweptDeckHit(
        prevFeetY: 910,
        feetY: 1010,
        prevX: 380,
        x: 380,
        footprintHalfWidth: 14,
        deck: moving,
      ),
      isNotNull,
    );
    // Same person, but crossing early (t≈0.1) when the deck was still far.
    expect(
      sweptDeckHit(
        prevFeetY: 990,
        feetY: 1090,
        prevX: 380,
        x: 380,
        footprintHalfWidth: 14,
        deck: moving,
      ),
      isNull,
    );
  });

  test('ground crossing is detected exactly once', () {
    expect(crossedGround(prevFeetY: 1070, feetY: 1085, groundY: 1080), isTrue);
    expect(crossedGround(prevFeetY: 1085, feetY: 1090, groundY: 1080), isFalse);
    expect(crossedGround(prevFeetY: 1000, feetY: 1050, groundY: 1080), isFalse);
  });
}
