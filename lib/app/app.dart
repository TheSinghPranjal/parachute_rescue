import 'package:flutter/material.dart';

import '../features/menu/main_menu_screen.dart';
import 'theme.dart';

class SkyRescueApp extends StatelessWidget {
  const SkyRescueApp({super.key, this.home = const MainMenuScreen()});

  final Widget home;


  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sky Rescue Panic',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: home,

  );
}
