import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/dsp.dart';
import '../../core/theme.dart';
import '../../models/phonics.dart';
import '../../models/profile.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';
import 'safari_island_view.dart';
import 'safari_level_view.dart';

/// Phonics Safari: five islands along a jungle path, one per vowel sound.
/// Every island and picture is always open; stars show what's been coloured.
class SafariMapView extends StatefulWidget {
  const SafariMapView({super.key});

  @override
  State<SafariMapView> createState() => _SafariMapViewState();
}

class _SafariMapViewState extends State<SafariMapView> {
  static bool _greeted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = Services.of(context);
      s.sound.music(true);
      s.sound.say(_greeted ? 'aria_pick' : 'aria_hello');
      _greeted = true;
    });
  }

  Future<void> _open(Vowel v) async {
    final s = Services.of(context);
    final pics = Phonics.island(v);
    await s.sound.hush();
    if (!mounted) return;
    // One picture on the island: go straight to it, as in v1.
    final page = pics.length == 1 ? SafariLevelView(picture: pics.first) : SafariIslandView(vowel: v);
    await Navigator.of(context).push(fadeRoute(page));
    if (!mounted) return;
    s.sound.music(true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final profile = s.store.active!;
    final size = MediaQuery.sizeOf(context);
    final badge = math.min(size.height * 0.3, size.width * 0.15);
    final practise = profile.level == PlayLevel.practise;

    return Scene(
      background: 'bg_safari',
      child: Stack(children: [
        // A gentle wave path across the screen.
        for (var i = 0; i < Vowel.values.length; i++)
          Align(
            alignment: Alignment(-0.62 + i * 0.31 + 0.08, i.isEven ? 0.28 : -0.3),
            child: Bob(
              phase: i * 0.2,
              child: () {
                final v = Vowel.values[i];
                final pics = Phonics.island(v);
                final done = pics.where((p) => (profile.pictureDone[p.id] ?? 0) > 0).length;
                return PictureBadge(
                  image: pics.first.image,
                  label: pics.length == 1
                      ? '${pics.first.id}, the ${v.letter} sound'
                      : 'The ${v.letter} island: ${pics.map((p) => p.id).join(', ')}',
                  size: badge,
                  stars: done,
                  total: pics.length,
                  letter: practise ? v.letter : null,
                  onTap: () => _open(v),
                );
              }(),
            ),
          ),
        Positioned(
          left: 4,
          bottom: 0,
          child: IgnorePointer(child: CharacterView(character: Character.aria, pose: 'idle', height: size.height * 0.28)),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: GlowIconButton(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
        ),
      ]),
    );
  }
}

/// A round picture button with progress stars underneath (one per picture)
/// and, in Practise level, the letter on a small tag.
class PictureBadge extends StatelessWidget {
  const PictureBadge({
    super.key,
    required this.image,
    required this.label,
    required this.size,
    required this.stars,
    required this.total,
    required this.onTap,
    this.letter,
  });

  final String image;
  final String label;
  final double size;
  final int stars;
  final int total;
  final String? letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = total > 0 && stars >= total;
    final ring = complete ? SP.amber : SP.lilac;
    return BouncyButton(
      label: label,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size * 1.18,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SP.cream,
              border: Border.all(color: ring, width: 5),
              boxShadow: [BoxShadow(color: ring.withValues(alpha: 0.45), blurRadius: 22)],
            ),
            padding: EdgeInsets.all(size * 0.14),
            child: Image.asset(image, fit: BoxFit.contain),
          ),
          if (letter != null)
            Positioned(
              left: -size * 0.02,
              top: -size * 0.02,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: SP.teal, border: Border.all(color: SP.cream, width: 3)),
                child: Text(letter!,
                    style: TextStyle(fontFamily: SP.font, fontWeight: FontWeight.w700, color: SP.night, fontSize: size * 0.18, height: 1)),
              ),
            ),
          Positioned(
            bottom: 0,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < total; i++)
                Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < stars ? SP.amber : SP.cream.withValues(alpha: 0.7),
                    size: size * 0.2,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
            ]),
          ),
        ]),
      ),
    );
  }
}
