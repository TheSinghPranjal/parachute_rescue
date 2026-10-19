import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../game/entities/parachute.dart';
import '../../game/entities/person.dart';
import '../../game/skins.dart';
import '../../providers/providers.dart';
import '../common/animated_doodle.dart';

/// Spend coins on canopy patterns and shirt colours. Skins never change size.
class SkinsScreen extends ConsumerWidget {
  const SkinsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SkinsScreen());

  Future<void> _tap(
    BuildContext context,
    WidgetRef ref,
    String id,
    int price, {
    required bool chute,
  }) async {
    final n = ref.read(progressProvider.notifier);
    final p = ref.read(progressProvider);
    if (!p.owns(id)) {
      final ok = await n.buy(id, price);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Need ${price - p.coins} more coins — rescue more people!',
              ),
            ),
          );
        }
        return;
      }
    }
    await (chute ? n.equipChute(id) : n.equipShirt(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
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
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedLabel(
                      'SKINS',
                      size: 34,
                      color: AppColors.yellow,
                      stroke: 6,
                    ),
                  ),
                ),
                Text(
                  '${p.coins} coins',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const OutlinedLabel(
              'PARACHUTES',
              size: 24,
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in ChuteSkin.all)
                  _SkinCard(
                    name: s.name,
                    price: s.price,
                    owned: p.owns(s.id),
                    equipped: p.chuteSkin == s.id,
                    onTap: () => unawaited(
                      _tap(context, ref, s.id, s.price, chute: true),
                    ),
                    paint: (c, size, t) {
                      c.translate(size.width / 2, size.height * 0.62);
                      Parachute.draw(
                        c,
                        Parachute.colorsFor(s, (t * 0.7).floor()),
                      );
                      c.translate(-kPersonSize.x / 2, -2);
                      Person.drawFigure(
                        c,
                        FigurePose.hanging,
                        t,
                        2,
                        shirt: ShirtSkin.byId(p.shirtSkin).color,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const OutlinedLabel('SHIRTS', size: 24, textAlign: TextAlign.left),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in ShirtSkin.all)
                  _SkinCard(
                    name: s.name,
                    price: s.price,
                    owned: p.owns(s.id),
                    equipped: p.shirtSkin == s.id,
                    onTap: () => unawaited(
                      _tap(context, ref, s.id, s.price, chute: false),
                    ),
                    paint: (c, size, t) {
                      c.translate(
                        size.width / 2 - kPersonSize.x / 2,
                        size.height / 2 - kPersonSize.y / 2,
                      );
                      Person.drawFigure(
                        c,
                        FigurePose.cheering,
                        t,
                        2,
                        shirt: s.color,
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.name,
    required this.price,
    required this.owned,
    required this.equipped,
    required this.onTap,
    required this.paint,
  });

  final String name;
  final int price;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;
  final DoodlePaint paint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        height: 150,
        padding: const EdgeInsets.all(6),
        decoration: doodleBox(
          color: equipped ? AppColors.yellow : AppColors.paper,
        ),
        child: Column(
          children: [
            Expanded(
              child: AnimatedDoodle(paint: paint, animate: equipped),
            ),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 14,
              ),
            ),
            Text(
              equipped ? 'EQUIPPED' : (owned ? 'TAP TO USE' : '$price coins'),
              style: TextStyle(
                fontSize: 15,
                color: owned ? AppColors.ink : AppColors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
