import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/dsp.dart';
import '../../core/theme.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';
import 'safari_level_view.dart';

/// Phonics Safari: five pictures along a jungle path, one per vowel sound.
/// Every picture is always open; a star shows the ones already coloured.
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
    await s.sound.hush();
    if (!mounted) return;
    await Navigator.of(context).push(fadeRoute(SafariLevelView(vowel: v)));
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

    return Scene(
      background: 'bg_safari',
      child: Stack(children: [
        // A gentle wave path across the screen.
        for (var i = 0; i < Vowel.values.length; i++)
          Align(
            alignment: Alignment(-0.62 + i * 0.31 + 0.08, i.isEven ? 0.28 : -0.3),
            child: Bob(
              phase: i * 0.2,
              child: _PictureBadge(
                vowel: Vowel.values[i],
                size: badge,
                done: profile.vowels[Vowel.values[i]]!.pictures > 0,
                onTap: () => _open(Vowel.values[i]),
              ),
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

class _PictureBadge extends StatelessWidget {
  const _PictureBadge({required this.vowel, required this.size, required this.done, required this.onTap});

  final Vowel vowel;
  final double size;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      label: '${vowel.word}, the ${vowel.letter} sound',
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SP.cream,
              border: Border.all(color: done ? SP.amber : SP.lilac, width: 5),
              boxShadow: [BoxShadow(color: (done ? SP.amber : SP.lilac).withValues(alpha: 0.45), blurRadius: 22)],
            ),
            padding: EdgeInsets.all(size * 0.14),
            child: Image.asset('assets/images/obj_${vowel.word}.webp', fit: BoxFit.contain),
          ),
          if (done)
            Positioned(
              right: -size * 0.04,
              top: -size * 0.04,
              child: Icon(Icons.star_rounded, color: SP.amber, size: size * 0.34, shadows: const [
                Shadow(color: Colors.black54, blurRadius: 8),
              ]),
            ),
        ]),
      ),
    );
  }
}
