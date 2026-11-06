import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';

/// Pip's Ice Hill: Pip glides up when the child sings high and down when
/// they sing low; any voice moves Pip forward to the next star.
///
/// Stars sit within the child's own measured range (pitch is already
/// relative to it), so a narrow range still reaches every height. Errorless:
/// if Pip arrives at a star at another height, the star drifts to meet Pip.
class IceHillView extends StatefulWidget {
  const IceHillView({super.key});

  @override
  State<IceHillView> createState() => _IceHillViewState();
}

/// Star heights for one round (0 = lowest the child sings, 1 = highest).
const hillStarHeights = [0.75, 0.25, 0.85, 0.4, 0.15, 0.65];

class _IceHillViewState extends ListeningState<IceHillView> {
  /// Pip's height, 0..1, following the child's pitch.
  double _height = 0.5;
  double _level = 0;

  /// Distance travelled, in star spacings; star i sits at i + 1.
  double _x = 0;
  final _stars = <double>[...hillStarHeights];
  int _caught = 0;
  double _waitAtStar = 0;
  double _silence = 0;
  bool _done = false;
  bool _showNext = false;
  double _sparkle = 0;
  final _trail = <double>[];

  bool get practise => profile.level == PlayLevel.practise;

  /// How close in height counts as catching the star.
  double get _reach => practise ? 0.14 : 0.22;

  @override
  void onStarted() => services.sound.say('hill_intro');

  @override
  void onVoice(VoiceFrame f, double dt) {
    final speaking = services.sound.speaking.value;
    _level = smoothTo(_level, f.voiced ? f.level : 0, 8, dt);
    _sparkle = math.max(0, _sparkle - dt);
    if (_done) {
      setState(() {});
      return;
    }
    if (f.voiced && f.pitchHz > 0) {
      _height = smoothTo(_height, f.pitchNorm.clamp(0.0, 1.0), 5, dt);
      _record(f.pitchHz);
    }
    if (f.voiced) _silence = 0;
    if (!f.voiced && !speaking) _silence += dt;

    final next = _caught + 1.0;
    if (_x < next) {
      // Any voice moves Pip forward; stop at the next star.
      if (f.voiced) _x = math.min(next, _x + 0.42 * dt);
    } else {
      // At the star: catch it when the heights meet. The star drifts
      // towards Pip after a moment, so it is always caught in the end.
      _waitAtStar += f.voiced ? dt : 0;
      if (_waitAtStar > 1.5) {
        _stars[_caught] = smoothTo(_stars[_caught], _height, 0.8, dt);
      }
      if ((_stars[_caught] - _height).abs() < _reach) _catch();
    }
    _trail.add(_height);
    if (_trail.length > 90) _trail.removeAt(0);

    if (!speaking && _silence > 12) {
      _silence = 0;
      services.sound.say('hill_intro');
    }
    setState(() {});
  }

  void _record(double hz) {
    if (profile.hillLowHz == 0 || hz < profile.hillLowHz) profile.hillLowHz = hz;
    if (hz > profile.hillHighHz) profile.hillHighHz = hz;
  }

  void _catch() {
    _caught++;
    _waitAtStar = 0;
    _sparkle = 1;
    profile.hillStars++;
    services.sound.sfx(Sfx.chime);
    if (_caught == _stars.length) {
      _done = true;
      profile.markDone('hill');
      services.store.save();
      services.sound.sfx(Sfx.tada);
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) services.sound.say('hill_all');
      });
      Future<void>.delayed(const Duration(milliseconds: 3200), () {
        if (mounted) setState(() => _showNext = true);
      });
    } else if (_caught == 1 || _caught == 4) {
      services.sound.say('hill_star');
    }
  }

  void _again() {
    setState(() {
      _x = 0;
      _caught = 0;
      _stars
        ..clear()
        ..addAll(hillStarHeights);
      _done = _showNext = false;
    });
    services.sound.say('hill_intro');
  }

  @override
  void dispose() {
    services.store.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pip = size.height * 0.26;
    return ColoredBox(
      color: SP.night,
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(
          painter: HillPainter(
            x: _x,
            stars: _stars,
            caught: _caught,
            trail: _trail,
            sparkle: profile.calmMode ? 0 : _sparkle,
          ),
        ),
        SafeArea(
          child: Stack(children: [
            LayoutBuilder(builder: (context, c) {
              final y = HillPainter.yFor(_height, c.maxHeight);
              return Stack(children: [
                Positioned(
                  left: c.maxWidth * HillPainter.pipX - pip * 0.5,
                  top: y - pip * 0.55,
                  child: IgnorePointer(
                    child: CharacterView(
                      character: Character.pip,
                      pose: _done ? 'wave' : (_height > 0.62 ? 'high' : (_height < 0.38 ? 'low' : 'idle')),
                      height: pip,
                      scale: 1 + 0.08 * _level,
                    ),
                  ),
                ),
              ]);
            }),
            Positioned(
              top: 12,
              left: 12,
              child: GlowIconButton(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: Semantics(
                label: '$_caught of ${_stars.length} stars',
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < _stars.length; i++)
                    Icon(i < _caught ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i < _caught ? SP.amber : SP.cream.withValues(alpha: 0.6), size: 34),
                ]),
              ),
            ),
            if (_showNext)
              Positioned(
                right: 24,
                top: 0,
                bottom: 0,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  GlowIconButton(icon: Icons.replay_rounded, label: 'Play again', size: 104, onTap: _again),
                  const SizedBox(height: 28),
                  GlowIconButton(
                      icon: Icons.home_rounded, label: 'Home', size: 104, color: SP.amber, onTap: () => Navigator.pop(context)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Night sky, snowy hills, the ice trail of Pip's recent heights and the
/// stars ahead. Pip stays at [pipX]; the world scrolls by.
class HillPainter extends CustomPainter {
  HillPainter({required this.x, required this.stars, required this.caught, required this.trail, required this.sparkle});

  final double x;
  final List<double> stars;
  final int caught;
  final List<double> trail;
  final double sparkle;

  static const pipX = 0.3;

  /// Screen width between stars, as a fraction of the width.
  static const spacing = 0.42;

  /// Screen y for a height 0..1 (low voice near the ground, high near the top).
  static double yFor(double h, double height) => height * (0.82 - 0.62 * h);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2A5C), Color(0xFF3B5BA0), Color(0xFF9FC3EA)],
        ).createShader(r),
    );
    // Faint fixed sky stars.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.5);
    final rand = math.Random(3);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height * 0.5), 1.2, dot);
    }
    // Snowy hills, scrolling slowly for depth.
    void hills(double base, double amp, double speed, Color c) {
      final path = Path()..moveTo(0, size.height);
      for (var px = 0.0; px <= size.width; px += size.width / 48) {
        final t = px / size.width + x * spacing * speed;
        path.lineTo(px, size.height * base + math.sin(t * math.pi * 3) * size.height * amp);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = c);
    }

    hills(0.78, 0.05, 0.3, const Color(0xFFDCE8F7));
    hills(0.88, 0.03, 0.6, Colors.white);

    // Ice trail: where Pip has been.
    if (trail.length > 1) {
      final path = Path();
      for (var i = 0; i < trail.length; i++) {
        final px = size.width * pipX - (trail.length - 1 - i) * size.width * 0.004;
        final py = yFor(trail[i], size.height);
        i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFBFF3FF).withValues(alpha: 0.7),
      );
    }

    // Stars ahead (and the one Pip is at).
    for (var i = caught; i < stars.length; i++) {
      final sx = size.width * (pipX + (i + 1 - x) * spacing);
      if (sx > size.width + 60) break;
      _star(canvas, Offset(sx, yFor(stars[i], size.height)), size.height * 0.055, SP.amber);
    }
    // A burst where the last star was caught.
    if (sparkle > 0) {
      final c = Offset(size.width * pipX, size.height * 0.5);
      for (var i = 0; i < 10; i++) {
        final a = i / 10 * math.pi * 2;
        final d = size.height * 0.25 * (1 - sparkle);
        _star(canvas, c + Offset(math.cos(a), math.sin(a)) * d, 8 * sparkle + 2,
            HSVColor.fromAHSV(sparkle, i * 36.0, 0.6, 1).toColor());
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  }

  @override
  bool shouldRepaint(covariant HillPainter old) => true;
}
