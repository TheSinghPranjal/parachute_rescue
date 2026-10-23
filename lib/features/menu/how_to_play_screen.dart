import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/utils/doodle.dart';
import '../../game/entities/fish.dart';
import '../../game/entities/landing_space.dart';
import '../../game/entities/parachute.dart';
import '../../game/entities/person.dart';
import '../../game/hazards/helicopter.dart';
import '../../game/hazards/ufo.dart';
import '../../game/terrain/terrain.dart';
import '../../providers/providers.dart';
import '../common/animated_doodle.dart';
import '../play/gameplay_screen.dart';

class _Step {
  const _Step(this.title, this.body, this.paint);
  final String title;
  final String body;
  final void Function(Canvas, Size, double, TerrainTheme) paint;
}

/// Five short animated steps drawn with the real game art.
class HowToPlayScreen extends ConsumerStatefulWidget {
  const HowToPlayScreen({super.key, this.playAfter = false});

  /// When true, finishing (or skipping) goes straight into a game.
  final bool playAfter;

  static Route<void> route({bool playAfter = false}) =>
      MaterialPageRoute(builder: (_) => HowToPlayScreen(playAfter: playAfter));

  @override
  ConsumerState<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends ConsumerState<HowToPlayScreen> {
  final _pages = PageController();
  int _index = 0;

  static final _steps = [
    const _Step(
      'TAP TO OPEN',
      'Tap a falling stick figure to pop their parachute. Too late and they hit the ground!',
      _paintTap,
    ),
    const _Step(
      'SWIPE FOR WIND',
      'Swipe left or right next to someone to blow a gust. It only pushes them.',
      _paintSwipe,
    ),
    const _Step(
      'LAND ON THE DECK',
      'Guide parachutists onto the moving boat, truck, cart, sled or raft.',
      _paintLand,
    ),
    const _Step(
      'DODGE DANGER',
      'Tap helicopters and UFOs to knock them out. Steer clear of lightning!',
      _paintHazards,
    ),
    const _Step(
      'BUILD A STREAK',
      'Rescues in a row earn bonus points. Open late for a DARING x2 bonus. Miss 3 and it’s game over.',
      _paintStreak,
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).setTutorialDone(true);
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (widget.playAfter) {
      unawaited(nav.pushReplacement(GameplayScreen.route()));
    } else {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final terrain = ref.watch(progressProvider.select((p) => p.terrain));
    final last = _index == _steps.length - 1;
    return Scaffold(
      backgroundColor: terrain.sky.top,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  DoodleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: OutlinedLabel(
                        'HOW TO PLAY',
                        size: 30,
                        color: AppColors.yellow,
                        stroke: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _steps.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final s = _steps[i];
                    return Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: doodleBox(
                              color: terrain.sky.bottom,
                              radius: 20,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: AnimatedDoodle(
                              paint: (c, size, t) =>
                                  s.paint(c, size, t, terrain),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedLabel(
                          '${i + 1}. ${s.title}',
                          size: 30,
                          color: Colors.white,
                          stroke: 6,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, height: 1.15),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: i == _index ? 22 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.ink : Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DoodleButton(
                      key: const Key('tutorial-skip'),
                      label: widget.playAfter ? 'SKIP & PLAY' : 'SKIP',
                      color: AppColors.paper,
                      fontSize: 20,
                      expand: true,
                      onPressed: () => unawaited(_finish()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DoodleButton(
                      key: const Key('tutorial-next'),
                      label: last
                          ? (widget.playAfter ? 'PLAY!' : 'GOT IT')
                          : 'NEXT',
                      color: last ? AppColors.green : AppColors.yellow,
                      fontSize: 20,
                      expand: true,
                      onPressed: () {
                        if (last) {
                          unawaited(_finish());
                        } else {
                          unawaited(
                            _pages.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOut,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ painters --

  static void _ground(Canvas c, Size s, TerrainTheme th) {
    final g = s.height * 0.8;
    c.drawRect(
      Rect.fromLTRB(0, g, s.width, s.height),
      Doodle.fill(th.groundFill),
    );
    c.drawLine(Offset(0, g), Offset(s.width, g), Doodle.stroke());
  }

  static void _figure(
    Canvas c,
    Offset head,
    FigurePose pose,
    double t, {
    bool chute = false,
    double inflate = 1,
  }) {
    c.save();
    c.translate(head.dx, head.dy);
    if (chute) Parachute.draw(c, ChutePalette.demo, inflate: inflate);
    c.translate(-kPersonSize.x / 2, -2);
    Person.drawFigure(c, pose, t, 5);
    c.restore();
  }

  static void _finger(Canvas c, Offset at, double press) {
    c.drawCircle(
      at,
      14 + press * 10,
      Doodle.stroke(AppColors.red.withValues(alpha: 1 - press), 3),
    );
    final hand = Doodle.box(
      Rect.fromCenter(center: at.translate(10, 26), width: 22, height: 40),
      radius: 10,
      seed: 400,
    );
    Doodle.inked(c, hand, const Color(0xFFFFE0C2), width: 2.4);
  }

  static void _paintTap(Canvas c, Size s, double t, TerrainTheme th) {
    _ground(c, s, th);
    final u = (t % 3) / 3;
    final x = s.width * 0.45;
    final opened = u > 0.35;
    final y = opened
        ? s.height * (0.32 + (u - 0.35) * 0.35)
        : s.height * (0.08 + u * 0.7);
    _figure(
      c,
      Offset(x, y),
      opened ? FigurePose.hanging : FigurePose.falling,
      t,
      chute: opened,
      inflate: opened ? math.min(1, (u - 0.35) * 10) : 0,
    );
    if (u > 0.25 && u < 0.5) _finger(c, Offset(x + 6, y + 30), (u - 0.25) * 4);
  }

  static void _paintSwipe(Canvas c, Size s, double t, TerrainTheme th) {
    _ground(c, s, th);
    final u = (t % 2.6) / 2.6;
    final drift = math.sin(u * math.pi) * s.width * 0.25;
    _figure(
      c,
      Offset(s.width * 0.35 + drift, s.height * 0.38),
      FigurePose.hanging,
      t,
      chute: true,
    );
    final y = s.height * 0.62;
    final x0 = s.width * 0.18;
    final x1 = x0 + s.width * 0.6 * math.min(1, u * 2.2);
    final wind = Doodle.stroke(AppColors.ink.withValues(alpha: 0.8), 3);
    c.drawPath(
      Doodle.wave(x0, x1, y, amplitude: 5, wavelength: 34, phase: t * 6),
      wind,
    );
    c.drawPath(
      Doodle.wave(
        x0 + 20,
        x1 - 10,
        y - 22,
        amplitude: 4,
        wavelength: 28,
        phase: t * 6,
      ),
      wind,
    );
    if (u < 0.5) _finger(c, Offset(x1, y), 0);
  }

  static void _paintLand(Canvas c, Size s, double t, TerrainTheme th) {
    _ground(c, s, th);
    final u = (t % 4) / 4;
    final g = s.height * 0.8;
    final boatX = s.width * (0.3 + 0.4 * u);
    c.save();
    c.translate(boatX, g - 18);
    c.scale(0.7);
    LandingSpace.drawVariant(c, th.landing, th.landingColors, 75, t);
    c.restore();
    final landT = 0.7;
    final px = s.width * 0.58;
    if (u < landT) {
      final y = s.height * 0.1 + (g - 18 - 56 - s.height * 0.1) * (u / landT);
      _figure(
        c,
        Offset(px + (boatX - px) * 0, y),
        FigurePose.hanging,
        t,
        chute: true,
      );
    } else {
      _figure(c, Offset(boatX + 6, g - 18 - 56), FigurePose.cheering, t);
      final tp = TextPainter(
        text: const TextSpan(
          text: '+100',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 30,
            color: Color(0xFF2F9E44),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(boatX - tp.width / 2, g - 150 - (u - landT) * 60));
    }
    c.save();
    c.translate(s.width * 0.75, s.height * 0.92);
    c.scale(0.5);
    Fish.drawVariant(c, th.fish, th.fishColors, t, 0.1);
    c.restore();
  }

  static void _paintHazards(Canvas c, Size s, double t, TerrainTheme th) {
    final h = th.hazards;
    c.save();
    c.translate(s.width * 0.32 + math.sin(t) * 20, s.height * 0.3);
    c.scale(0.9);
    Helicopter.drawArt(c, t, h.helicopter, h.helicopterAccent);
    c.restore();
    if ((t % 1.2) < 0.4) {
      Doodle.inked(
        c,
        Doodle.burst(
          Offset(s.width * 0.32 + math.sin(t) * 20, s.height * 0.3),
          16,
          seed: 9,
        ),
        Colors.white,
        width: 2,
      );
    }
    c.save();
    c.translate(s.width * 0.7, s.height * 0.62 + math.sin(t * 2) * 8);
    c.scale(0.8);
    Ufo.drawArt(c, t, h.ufo, h.ufoDome);
    c.restore();
    final cloud = Doodle.cloud(
      Offset(s.width * 0.75, s.height * 0.16),
      120,
      seed: 161,
    );
    Doodle.inked(c, cloud, h.stormCloud);
    if ((t % 2) > 1.6) {
      c.drawPath(
        Doodle.line([
          Offset(s.width * 0.75, s.height * 0.24),
          Offset(s.width * 0.71, s.height * 0.34),
          Offset(s.width * 0.77, s.height * 0.38),
          Offset(s.width * 0.72, s.height * 0.5),
        ], jitter: 0),
        Doodle.stroke(h.bolt, 5),
      );
    }
  }

  static void _paintStreak(Canvas c, Size s, double t, TerrainTheme th) {
    _ground(c, s, th);
    final g = s.height * 0.8;
    c.save();
    c.translate(s.width * 0.5, g - 18);
    c.scale(0.8);
    LandingSpace.drawVariant(c, th.landing, th.landingColors, 75, t);
    c.restore();
    for (var i = 0; i < 3; i++) {
      _figure(
        c,
        Offset(s.width * (0.38 + i * 0.1), g - 20 - 56),
        FigurePose.cheering,
        t + i,
      );
    }
    final n = (t % 3).floor() + 1;
    final tp = TextPainter(
      text: TextSpan(
        text: 'STREAK x${n + 2}',
        style: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 34,
          color: AppColors.blue,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(s.width / 2 - tp.width / 2, s.height * 0.18));
  }
}

/// Fixed canopy colours for tutorial art.
abstract final class ChutePalette {
  static const demo = [Color(0xFFE8504F), Color(0xFFFFFFFF)];
}
