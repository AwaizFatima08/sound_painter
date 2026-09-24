import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/parent_gate.dart';
import '../dashboard/parent_zone_view.dart';
import '../onboarding/warmup_view.dart';
import 'home_view.dart';

/// "Tap your animal friend!": picks which child is playing, so each child
/// keeps their own voice range, paintings and progress.
class ProfilePickerView extends StatefulWidget {
  const ProfilePickerView({super.key});

  @override
  State<ProfilePickerView> createState() => _ProfilePickerViewState();
}

class _ProfilePickerViewState extends State<ProfilePickerView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = Services.of(context);
      s.sound.music(true);
      s.sound.say('choose_friend');
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final size = MediaQuery.sizeOf(context);
    final profiles = s.store.profiles;
    final d = math.min(size.height * 0.32, (size.width - 80) / math.max(3, profiles.length) - 24);

    return Scene(
      background: 'bg_home',
      child: Stack(children: [
        Center(
          child: Wrap(spacing: 24, runSpacing: 24, alignment: WrapAlignment.center, children: [
            for (final p in profiles)
              BouncyButton(
                label: p.displayName,
                onTap: () async {
                  s.store.active = p;
                  await s.sound.hush();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(fadeRoute(
                    p.warmedUp ? const HomeView() : const WarmupView(next: HomeView()),
                  ));
                },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: SP.cream, width: 4),
                      boxShadow: [BoxShadow(color: SP.lilac.withValues(alpha: 0.5), blurRadius: 20)],
                    ),
                    child: ClipOval(child: Image.asset('assets/images/avatar_${p.avatar.name}.webp', fit: BoxFit.cover)),
                  ),
                  if (p.nickname.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(p.nickname, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
          ]),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Opacity(
            opacity: 0.75,
            child: GlowIconButton(
              icon: Icons.lock_rounded,
              label: 'Grown-ups',
              size: 56,
              color: SP.lilac,
              onTap: () async {
                if (!await showParentGate(context) || !context.mounted) return;
                await s.sound.pauseAll();
                if (!context.mounted) return;
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentZoneView()));
                if (context.mounted) setState(() {});
              },
            ),
          ),
        ),
      ]),
    );
  }
}
