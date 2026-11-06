import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../models/stickers.dart';
import '../../services/services.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/parent_gate.dart';
import '../../widgets/rest_overlay.dart';
import '../animals/animals_view.dart';
import '../balloon/balloon_view.dart';
import '../canvas/free_canvas_view.dart';
import '../dashboard/parent_zone_view.dart';
import '../gallery/gallery_view.dart';
import '../hill/ice_hill_view.dart';
import '../lanterns/lanterns_view.dart';
import '../safari/safari_map_view.dart';
import '../stickers/sticker_book_view.dart';
import 'profile_picker_view.dart';

/// The child's hub: big floating pictures, no words.
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

  static Widget _page(Activity a) => switch (a) {
        Activity.canvas => const FreeCanvasView(),
        Activity.safari => const SafariMapView(),
        Activity.animals => const AnimalsView(),
        Activity.hill => const IceHillView(),
        Activity.lanterns => const LanternsView(),
        Activity.balloon => const BalloonView(),
      };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final profile = s.store.active;
    if (profile == null) return const SizedBox();
    final badge = math.min(size.height * 0.33, size.width * 0.16);
    final gap = SizedBox(width: size.width * 0.03);

    return Scene(
      background: 'bg_home',
      child: Stack(children: [
        Align(
          alignment: const Alignment(0, 0.25),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Badge(asset: 'badge_canvas', label: 'Free Canvas: paint with your voice', size: badge, phase: 0,
                  onTap: () => _open(const FreeCanvasView())),
              gap,
              _Badge(asset: 'badge_safari', label: 'Phonics Safari: colour pictures with sounds', size: badge, phase: 0.15,
                  onTap: () => _open(const SafariMapView())),
              gap,
              _Badge(asset: 'badge_animals', label: 'Animal Sounds: wake the sleepy animals', size: badge, phase: 0.3,
                  onTap: () => _open(const AnimalsView())),
              gap,
              _Badge(asset: 'badge_hill', label: "Pip's Ice Hill: sing high and low", size: badge, phase: 0.45,
                  onTap: () => _open(const IceHillView())),
            ]),
            SizedBox(height: size.height * 0.03),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Badge(asset: 'badge_lanterns', label: "Ollie's Lanterns: quiet and loud", size: badge, phase: 0.6,
                  onTap: () => _open(const LanternsView())),
              gap,
              _Badge(asset: 'badge_balloon', label: 'Breath Balloon: hold a long sound', size: badge, phase: 0.75,
                  onTap: () => _open(const BalloonView())),
              gap,
              _Badge(asset: 'badge_gallery', label: 'My paintings', size: badge, phase: 0.9,
                  onTap: () => _open(const GalleryView())),
              gap,
              _StickerBadge(size: badge, onTap: () => _open(const StickerBookView())),
            ]),
          ]),
        ),
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(child: _TodayPath(profile: profile, onOpen: (a) => _open(_page(a)))),
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

/// Three small pictures along the top: today's suggested activities, each
/// ticked once finished today. A fixed, predictable routine for the day.
class _TodayPath extends StatelessWidget {
  const _TodayPath({required this.profile, required this.onOpen});

  final Profile profile;
  final void Function(Activity a) onOpen;

  @override
  Widget build(BuildContext context) {
    final path = TodayPath.forDay(DateTime.now());
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < path.length; i++) ...[
        if (i > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              for (var d = 0; d < 3; d++)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: SP.cream.withValues(alpha: 0.6)),
                ),
            ]),
          ),
        () {
          final a = path[i];
          final done = profile.doneToday(a.name);
          return BouncyButton(
            label: "Today's path: ${a.title}${done ? ', done' : ''}",
            onTap: () => onOpen(a),
            child: SizedBox(
              width: 68,
              height: 68,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SP.cream,
                    border: Border.all(color: done ? SP.amber : SP.lilac, width: 3),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/images/${a.badge}.webp', fit: BoxFit.contain),
                ),
                if (done)
                  const Positioned(
                    right: -4,
                    bottom: -4,
                    child: Icon(Icons.check_circle_rounded, color: SP.teal, size: 30,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
                  ),
              ]),
            ),
          );
        }(),
      ],
    ]);
  }
}

/// The sticker book's badge, drawn in code: a little book with a star.
class _StickerBadge extends StatelessWidget {
  const _StickerBadge({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Bob(
      phase: 0.95,
      amount: 10,
      child: BouncyButton(
        label: 'My sticker book',
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Container(
              width: size * 0.72,
              height: size * 0.86,
              decoration: BoxDecoration(
                color: SP.pink,
                borderRadius: BorderRadius.circular(size * 0.08),
                border: Border.all(color: SP.plum, width: 5),
                boxShadow: [BoxShadow(color: SP.pink.withValues(alpha: 0.4), blurRadius: 18)],
              ),
              child: Icon(Icons.star_rounded, color: SP.amber, size: size * 0.5,
                  shadows: const [Shadow(color: SP.plum, blurRadius: 2)]),
            ),
          ),
        ),
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
