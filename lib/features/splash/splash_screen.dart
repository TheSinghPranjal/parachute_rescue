import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/doodle.dart';
import '../../game/entities/parachute.dart';
import '../../game/entities/person.dart';
import '../../game/skins.dart';
import '../common/animated_doodle.dart';
import '../menu/main_menu_screen.dart';

/// How long the splash stays fully visible before it fades to the menu.
const Duration kSplashHold = Duration(milliseconds: 2000);

const Duration _kFade = Duration(milliseconds: 400);

const String _kBearAsset = 'assets/branding/lazy_bear_club.png';

/// Sky colours for the intro. The byline itself always sits on a paper card
/// so the credit stays dark-on-light in either theme.
@immutable
class _SplashPalette {
  const _SplashPalette({
    required this.skyTop,
    required this.skyBottom,
    required this.cloud,
    required this.sun,
    required this.titleStroke,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color cloud;
  final Color sun;
  final Color titleStroke;

  static const light = _SplashPalette(
    skyTop: Color(0xFFBFE6FA),
    skyBottom: Color(0xFFE6F6FD),
    cloud: Color(0xFFFFFFFF),
    sun: Color(0xFFFFD35A),
    titleStroke: AppColors.ink,
  );

  static const dark = _SplashPalette(
    skyTop: Color(0xFF143044),
    skyBottom: Color(0xFF1C4A66),
    cloud: Color(0xFFE7F3FA),
    sun: Color(0xFFFFD35A),
    titleStroke: AppColors.paper,
  );

  static _SplashPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Branded intro: the game title, then "by / The Lazy Bear Club".
///
/// Replaces itself with [next] (the main menu, unless a test says otherwise)
/// after [hold].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.next, this.hold = kSplashHold});

  final Widget? next;
  final Duration hold;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Timer _timer;
  var _opened = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.hold, _openNext);
  }

  void _openNext() {
    if (_opened || !mounted) return;
    _opened = true;
    final next = widget.next ?? const MainMenuScreen();
    unawaited(
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: _kFade,
          reverseTransitionDuration: _kFade,
          pageBuilder: (context, animation, secondaryAnimation) => next,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _SplashPalette.of(context);
    return Scaffold(
      key: const Key('splash-screen'),
      backgroundColor: palette.skyTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _SkyPainter(palette),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortest = constraints.biggest.shortestSide;
                final tablet = shortest >= 600;
                final titleSize = tablet ? 76.0 : 52.0;
                final mascotScale = titleSize / 52;
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          math.max(12, constraints.maxHeight * 0.03),
                          16,
                          0,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedLabel(
                                'PARACHUTE',
                                size: titleSize,
                                color: AppColors.yellow,
                                stroke: titleSize * 0.17,
                                strokeColor: palette.titleStroke,
                              ),
                              OutlinedLabel(
                                'RESCUE!',
                                size: titleSize * 1.16,
                                color: AppColors.blue,
                                stroke: titleSize * 0.17,
                                strokeColor: palette.titleStroke,
                              ),
                              SizedBox(height: tablet ? 12 : 4),
                              SizedBox(
                                width: 120 * mascotScale,
                                height: 156 * mascotScale,
                                child: const AnimatedDoodle(
                                  paint: _paintMascot,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.max(1, constraints.maxHeight * 0.46),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Byline(
                            iconSize: tablet ? 80 : 64,
                            bySize: tablet ? 32 : 26,
                            studioSize: tablet ? 28 : 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void _paintMascot(Canvas canvas, Size size, double t) {
  canvas.translate(size.width / 2, size.height * 0.62 + math.sin(t * 2) * 4);
  canvas.rotate(math.sin(t * 1.3) * 0.06);
  canvas.scale(size.width / 120);
  Parachute.draw(canvas, ChuteSkin.classicPairs.first);
  canvas.translate(-kPersonSize.x / 2, -2);
  Person.drawFigure(canvas, FigurePose.hanging, t, 3);
}

class _Byline extends StatelessWidget {
  const _Byline({
    required this.iconSize,
    required this.bySize,
    required this.studioSize,
  });

  final double iconSize;
  final double bySize;
  final double studioSize;

  @override
  Widget build(BuildContext context) {
    final radius = iconSize * 0.22;
    return Container(
      key: const Key('splash-byline'),
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 12),
      decoration: doodleBox(color: AppColors.paper, radius: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'by',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.hand,
              fontSize: bySize,
              height: 1,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const Key('lazy-bear-icon'),
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  _kBearAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'The Lazy Bear Club',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: studioSize,
                  height: 1.05,
                  letterSpacing: 0.3,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.palette);

  final _SplashPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyBottom],
        ).createShader(rect),
    );

    final sunR = (size.shortestSide * 0.065).clamp(20.0, 36.0);
    final sun = Offset(
      math.max(sunR * 1.8, size.width - sunR * 2.6),
      sunR * 2.2,
    );
    final ray = Doodle.stroke(palette.sun, 3);
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * math.pi * 2;
      canvas.drawLine(
        sun + Offset(math.cos(a), math.sin(a)) * (sunR + 8),
        sun + Offset(math.cos(a), math.sin(a)) * (sunR + 22),
        ray,
      );
    }
    Doodle.inked(
      canvas,
      Doodle.blob(sun, sunR, sunR, seed: 210),
      palette.sun,
      width: 2.6,
    );

    // Keep clouds in the top band so they don't sit on the title.
    final leftW = math.min(size.shortestSide * 0.30, 180.0);
    _cloud(canvas, Offset(leftW * 0.42, leftW * 0.2), leftW, 3);
    final rightW = math.min(size.shortestSide * 0.18, 120.0);
    final sunLeft = size.width - sunR * 3.4;
    final rightX = math.min(size.width * 0.56, sunLeft - rightW * 0.35);
    if (rightX > leftW) {
      _cloud(canvas, Offset(rightX, rightW * 0.28), rightW, 9);
    }
  }

  void _cloud(Canvas canvas, Offset center, double cloudWidth, int seed) {
    Doodle.inked(
      canvas,
      Doodle.cloud(center, cloudWidth, seed: seed),
      palette.cloud,
      width: 2.4,
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
