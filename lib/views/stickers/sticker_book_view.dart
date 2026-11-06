import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/stickers.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';

/// The sticker book: every sticker the app can give, earned ones in full
/// colour, the rest as soft shadows to discover. No counts, no pressure.
class StickerBookView extends StatelessWidget {
  const StickerBookView({super.key});

  static const _shadow = ColorFilter.matrix([
    0, 0, 0, 0, 255, //
    0, 0, 0, 0, 255,
    0, 0, 0, 0, 255,
    0, 0, 0, 0.18, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final profile = Services.of(context).store.active!;
    final stickers = Stickers.all();
    final size = MediaQuery.sizeOf(context);
    final cell = (size.height * 0.2).clamp(72.0, 140.0);
    return Scene(
      background: 'bg_home',
      dim: 0.55,
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(110, 16, 24, 16),
          child: GridView.extent(
            maxCrossAxisExtent: cell,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: [
              for (final s in stickers)
                () {
                  final earned = s.earned(profile);
                  return Semantics(
                    label: earned ? 'Sticker: ${s.label}' : 'A sticker still to find',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: earned ? SP.cream : SP.card.withValues(alpha: 0.6),
                        border: Border.all(color: earned ? SP.amber : SP.cardLine, width: earned ? 4 : 2),
                        boxShadow: earned ? [BoxShadow(color: SP.amber.withValues(alpha: 0.35), blurRadius: 14)] : null,
                      ),
                      padding: EdgeInsets.all(cell * 0.14),
                      child: earned
                          ? Image.asset(s.image, fit: BoxFit.contain)
                          : ColorFiltered(colorFilter: _shadow, child: Image.asset(s.image, fit: BoxFit.contain)),
                    ),
                  );
                }(),
            ],
          ),
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
