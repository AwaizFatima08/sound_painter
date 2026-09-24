import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/parent_gate.dart';
import '../../widgets/rest_overlay.dart';
import '../canvas/free_canvas_view.dart';
import '../dashboard/parent_zone_view.dart';
import '../gallery/gallery_view.dart';
import '../safari/safari_map_view.dart';
import 'profile_picker_view.dart';

/// The child's hub: three big floating pictures, no words.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  late final Services s = Services.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      s.session.begin(s.store.active!);
      s.session.timeUp.addListener(_onTimeUp);
      s.sound.music(true);
      s.sound.say('home_hello');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    s.session.timeUp.removeListener(_onTimeUp);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      s.sound.pauseAll();
      s.session.end();
    } else if (state == AppLifecycleState.resumed) {
      final p = s.store.active;
      if (p != null) s.session.begin(p);
      if (ModalRoute.of(context)?.isCurrent == true) s.sound.music(true);
    }
  }

  void _onTimeUp() {
    // Listening screens show their own rest screen; this covers the hub.
    if (s.session.timeUp.value && mounted && ModalRoute.of(context)?.isCurrent == true) {
      s.sound.music(false);
      Navigator.of(context).push(restRoute(context)).then((_) => s.sound.music(true));
    }
  }

  Future<void> _open(Widget page) async {
    await s.sound.hush();
    if (!mounted) return;
    final result = await Navigator.of(context).push(fadeRoute(page));
    if (!mounted) return;
    s.sound.music(true);
    if (result == true && page is FreeCanvasView) s.sound.say('canvas_saved');
    setState(() {});
  }

  Future<void> _parentZone() async {
    if (!await showParentGate(context) || !mounted) return;
    await s.sound.pauseAll();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentZoneView()));
    if (!mounted) return;
    if (s.store.profiles.isEmpty) return; // the zone restarted setup
    s.session.begin(s.store.active!);
    s.sound.music(true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final profile = s.store.active;
    if (profile == null) return const SizedBox();
    final badge = math.min(size.height * 0.42, size.width * 0.24);

    return Scene(
      background: 'bg_home',
      child: Stack(children: [
        Align(
          alignment: const Alignment(0, 0.1),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Badge(asset: 'badge_canvas', label: 'Free Canvas: paint with your voice', size: badge, phase: 0,
                onTap: () => _open(const FreeCanvasView())),
            SizedBox(width: size.width * 0.03),
            _Badge(asset: 'badge_safari', label: 'Phonics Safari: colour pictures with sounds', size: badge, phase: 0.33,
                onTap: () => _open(const SafariMapView())),
            SizedBox(width: size.width * 0.03),
            _Badge(asset: 'badge_gallery', label: 'My paintings', size: badge, phase: 0.66,
                onTap: () => _open(const GalleryView())),
          ]),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _AvatarButton(
            avatar: profile.avatar,
            label: 'Playing as ${profile.displayName}. Tap to change.',
            onTap: s.store.profiles.length > 1
                ? () async {
                    s.session.end();
                    await s.sound.hush();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(fadeRoute(const ProfilePickerView()));
                  }
                : null,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Opacity(
            opacity: 0.75,
            child: GlowIconButton(icon: Icons.lock_rounded, label: 'Grown-ups', size: 56, color: SP.lilac, onTap: _parentZone),
          ),
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.asset, required this.label, required this.size, required this.phase, required this.onTap});

  final String asset;
  final String label;
  final double size;
  final double phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Bob(
      phase: phase,
      amount: 10,
      child: BouncyButton(
        label: label,
        onTap: onTap,
        child: Image.asset('assets/images/$asset.webp', width: size, height: size),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.avatar, required this.label, this.onTap});

  final Avatar avatar;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      label: label,
      onTap: onTap,
      sound: onTap != null,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SP.cream, width: 3),
          boxShadow: [BoxShadow(color: SP.lilac.withValues(alpha: 0.5), blurRadius: 14)],
        ),
        child: ClipOval(child: Image.asset('assets/images/avatar_${avatar.name}.webp', fit: BoxFit.cover)),
      ),
    );
  }
}
