import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/services.dart';
import 'kid_widgets.dart';
import 'parent_gate.dart';

/// Shown when the parent's session length is reached: Pip waves goodbye and
/// the mic stays off. Only a grown-up can choose to keep playing.
Route<void> restRoute(BuildContext context) => fadeRoute(const _RestScreen());

class _RestScreen extends StatefulWidget {
  const _RestScreen();

  @override
  State<_RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<_RestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Services.of(context).sound.say('session_end'));
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: false,
      child: Scene(
        background: 'bg_home',
        dim: 0.35,
        child: Stack(children: [
          Center(
            child: Bob(child: CharacterView(character: Character.pip, pose: 'wave', height: h * 0.6)),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GlowIconButton(
              icon: Icons.lock_rounded,
              label: 'Grown-ups: keep playing',
              size: 56,
              color: SP.lilac,
              onTap: () async {
                final s = Services.of(context);
                if (await showParentGate(context) && context.mounted) {
                  s.session.extend();
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ]),
      ),
    );
  }
}
