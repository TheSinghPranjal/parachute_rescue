import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/sound_toggles.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onMenu,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x88000000),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: doodleBox(radius: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OutlinedLabel(
                    'PAUSED',
                    size: 40,
                    color: AppColors.yellow,
                  ),
                  const SizedBox(height: 18),
                  DoodleButton(
                    label: 'RESUME',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onResume,
                    expand: true,
                  ),
                  const SizedBox(height: 12),
                  DoodleButton(
                    label: 'RESTART',
                    icon: Icons.refresh_rounded,
                    color: AppColors.blue,
                    onPressed: onRestart,
                    expand: true,
                  ),
                  const SizedBox(height: 12),
                  DoodleButton(
                    label: 'MAIN MENU',
                    icon: Icons.home_rounded,
                    color: AppColors.paper,
                    onPressed: onMenu,
                    expand: true,
                  ),
                  const SizedBox(height: 14),
                  const SoundToggles(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
