import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/config/game_config.dart';
import '../../providers/providers.dart';
import 'how_to_play_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SettingsScreen());

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.ink, width: 3),
        ),
        title: const Text(
          'Reset all data?',
          style: TextStyle(fontFamily: AppFonts.display),
        ),
        content: const Text(
          'Best score, coins, skins and settings will be erased. This can’t be undone.',
          style: TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 20)),
          ),
          TextButton(
            key: const Key('confirm-reset'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reset',
              style: TextStyle(fontSize: 20, color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(progressProvider.notifier).resetAll();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Local data reset')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                DoodleIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 16),
                const Flexible(
                  child: OutlinedLabel(
                    'SETTINGS',
                    size: 34,
                    color: AppColors.yellow,
                    stroke: 6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: doodleBox(radius: 18),
              child: Column(
                children: [
                  _switch(
                    'Sound effects',
                    Icons.volume_up_rounded,
                    s.sfx,
                    (v) => unawaited(n.setSfx(v)),
                    const Key('set-sfx'),
                  ),
                  _switch(
                    'Music',
                    Icons.music_note_rounded,
                    s.music,
                    (v) => unawaited(n.setMusic(v)),
                    const Key('set-music'),
                  ),
                  _switch(
                    'Vibration',
                    Icons.vibration_rounded,
                    s.haptics,
                    (v) => unawaited(n.setHaptics(v)),
                    const Key('set-haptics'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _DropSpeedPicker(
              level: s.dropSpeed,
              onChanged: (v) => unawaited(n.setDropSpeed(v)),
            ),
            const SizedBox(height: 18),
            DoodleButton(
              label: 'REPLAY TUTORIAL',
              icon: Icons.school_rounded,
              color: AppColors.blue,
              textColor: Colors.white,
              fontSize: 20,
              expand: true,
              onPressed: () {
                unawaited(n.setTutorialDone(false));
                unawaited(Navigator.of(context).push(HowToPlayScreen.route()));
              },
            ),
            const SizedBox(height: 12),
            DoodleButton(
              key: const Key('reset-data'),
              label: 'RESET LOCAL DATA',
              icon: Icons.delete_forever_rounded,
              color: AppColors.red,
              textColor: Colors.white,
              fontSize: 20,
              expand: true,
              onPressed: () => unawaited(_confirmReset(context, ref)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: doodleBox(radius: 18),
              child: const Text(
                'Parachute Rescue\n'
                'An original doodle arcade game built with Flutter, Flame and Riverpod. '
                'All art is drawn in code; sound effects are synthesized originals.\n'
                'Fonts: Lilita One & Patrick Hand (SIL Open Font License).',
                style: TextStyle(fontSize: 18, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    Key key,
  ) => SwitchListTile(
    key: key,
    value: value,
    onChanged: onChanged,
    secondary: Icon(icon, color: AppColors.ink),
    title: Text(
      label,
      style: const TextStyle(fontFamily: AppFonts.display, fontSize: 20),
    ),
  );
}

/// Five-step drop-speed control: − / + buttons around a row of pips.
class _DropSpeedPicker extends StatelessWidget {
  const _DropSpeedPicker({required this.level, required this.onChanged});

  final int level;
  final ValueChanged<int> onChanged;

  static const _labels = {
    1: 'Very slow',
    2: 'Slow',
    3: 'Normal',
    4: 'Fast',
    5: 'Very fast',
  };

  Widget _step(IconData icon, String tooltip, int to, Key key) {
    final enabled = to >= DropSpeed.min && to <= DropSpeed.max;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: DoodleIconButton(
        key: key,
        icon: icon,
        tooltip: tooltip,
        size: 44,
        onPressed: () {
          if (enabled) onChanged(to);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: doodleBox(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: AppColors.ink),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Drop speed',
                  style: TextStyle(fontFamily: AppFonts.display, fontSize: 20),
                ),
              ),
              Text(
                _labels[level]!,
                key: const Key('drop-speed-label'),
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _step(
                Icons.remove_rounded,
                'Slower',
                level - 1,
                const Key('drop-speed-down'),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = DropSpeed.min; i <= DropSpeed.max; i++)
                      GestureDetector(
                        onTap: () => onChanged(i),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= level
                                ? AppColors.orange
                                : AppColors.paper,
                            border: Border.all(
                              color: AppColors.ink,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _step(
                Icons.add_rounded,
                'Faster',
                level + 1,
                const Key('drop-speed-up'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
