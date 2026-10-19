import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../providers/providers.dart';

/// Sound-effects and music toggle buttons, backed by persisted settings.
class SoundToggles extends ConsumerWidget {
  const SoundToggles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DoodleIconButton(
          key: const Key('toggle-sfx'),
          icon: s.sfx ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          tooltip: s.sfx ? 'Sound on' : 'Sound off',
          color: s.sfx ? AppColors.paper : Colors.grey.shade400,
          onPressed: () => unawaited(n.setSfx(!s.sfx)),
        ),
        const SizedBox(width: 14),
        DoodleIconButton(
          key: const Key('toggle-music'),
          icon: s.music ? Icons.music_note_rounded : Icons.music_off_rounded,
          tooltip: s.music ? 'Music on' : 'Music off',
          color: s.music ? AppColors.paper : Colors.grey.shade400,
          onPressed: () => unawaited(n.setMusic(!s.music)),
        ),
      ],
    );
  }
}
