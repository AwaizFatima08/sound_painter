import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/dsp.dart';
import '../../core/theme.dart';
import '../../models/phonics.dart';
import '../../models/profile.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';
import 'safari_level_view.dart';
import 'safari_map_view.dart';

/// One vowel island: its pictures side by side. A star under each picture
/// shows it has been coloured; the letter shows in Practise level.
class SafariIslandView extends StatefulWidget {
  const SafariIslandView({super.key, required this.vowel});

  final Vowel vowel;

  @override
  State<SafariIslandView> createState() => _SafariIslandViewState();
}

class _SafariIslandViewState extends State<SafariIslandView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Services.of(context).sound.say('aria_pick'));
  }

  Future<void> _open(PhonicsPicture p) async {
    final s = Services.of(context);
    await s.sound.hush();
    if (!mounted) return;
    await Navigator.of(context).push(fadeRoute(SafariLevelView(picture: p)));
    if (!mounted) return;
    s.sound.music(true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final profile = s.store.active!;
    final size = MediaQuery.sizeOf(context);
    final pics = Phonics.island(widget.vowel);
    final badge = math.min(size.height * 0.38, size.width * 0.2);
    final practise = profile.level == PlayLevel.practise;

    return Scene(
      background: 'bg_safari',
      dim: 0.2,
      child: Stack(children: [
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < pics.length; i++) ...[
              if (i > 0) SizedBox(width: size.width * 0.04),
              Bob(
                phase: i * 0.25,
                child: PictureBadge(
                  image: pics[i].image,
                  label: '${pics[i].id}, the ${widget.vowel.letter} sound',
                  size: badge,
                  stars: (profile.pictureDone[pics[i].id] ?? 0) > 0 ? 1 : 0,
                  total: 1,
                  letter: practise ? widget.vowel.letter : null,
                  onTap: () => _open(pics[i]),
                ),
              ),
            ],
          ]),
        ),
        Positioned(
          left: 4,
          bottom: 0,
          child: IgnorePointer(child: CharacterView(character: Character.aria, pose: 'idle', height: size.height * 0.28)),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: GlowIconButton(icon: Icons.map_rounded, label: 'Back to the map', onTap: () => Navigator.pop(context)),
        ),
        if (pics.every((p) => (profile.pictureDone[p.id] ?? 0) > 0))
          Positioned(
            top: 12,
            right: 16,
            child: Icon(Icons.emoji_events_rounded, color: SP.amber, size: 72, semanticLabel: 'Island complete',
                shadows: const [Shadow(color: Colors.black54, blurRadius: 10)]),
          ),
      ]),
    );
  }
}
