import 'package:flutter/material.dart';

import '../features/splash/splash_screen.dart';
import 'theme.dart';

class SkyRescueApp extends StatelessWidget {
  const SkyRescueApp({super.key, this.home = const SplashScreen()});

  /// First screen. Defaults to the branded splash, which opens the main menu.
  /// Tests pass a screen directly so they don't wait on the splash.
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Parachute Rescue',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: home,
  );
}
