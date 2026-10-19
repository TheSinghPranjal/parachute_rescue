import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../game/entities/fish.dart';
import '../../game/entities/landing_space.dart';
import '../../game/terrain/terrain.dart';
import '../common/animated_doodle.dart';

/// Horizontal list of terrain cards. All terrains are free to pick.
class TerrainPicker extends StatelessWidget {
  const TerrainPicker({
    super.key,
    required this.selectedId,
    required this.onSelect,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: TerrainTheme.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final t = TerrainTheme.all[i];
          final selected = t.id == selectedId;
          return GestureDetector(
            key: Key('terrain-${t.id}'),
            onTap: () => onSelect(t.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 128,
              decoration: doodleBox(
                color: selected ? AppColors.yellow : AppColors.paper,
              ),
              transform: Matrix4.translationValues(0, selected ? -3 : 0, 0),
              padding: const EdgeInsets.all(5),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TerrainPreview(theme: t, animate: selected),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A tiny live scene: sky, ground, the terrain's landing space and predator.
class TerrainPreview extends StatelessWidget {
  const TerrainPreview({super.key, required this.theme, this.animate = true});

  final TerrainTheme theme;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AnimatedDoodle(
      animate: animate,
      paint: (canvas, size, t) {
        final ground = size.height * 0.62;
        canvas.drawRect(Offset.zero & size, Paint()..color = theme.sky.top);
        canvas.drawRect(
          Rect.fromLTRB(0, ground, size.width, size.height),
          Paint()..color = theme.groundFill,
        );
        canvas.save();
        canvas.translate(size.width * 0.5, ground - 10);
        canvas.scale(0.42);
        LandingSpace.drawVariant(
          canvas,
          theme.landing,
          theme.landingColors,
          75,
          t,
        );
        canvas.restore();
        canvas.save();
        canvas.translate(size.width * 0.3, size.height * 0.86);
        canvas.scale(0.3);
        Fish.drawVariant(canvas, theme.fish, theme.fishColors, t, 0.2);
        canvas.restore();
      },
    );
  }
}
