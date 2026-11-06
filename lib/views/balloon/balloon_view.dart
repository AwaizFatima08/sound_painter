import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';

/// Breath Balloon: holding one sound blows up a balloon until it floats away.
///
/// Builds long, steady voicing. The balloon grows while the child sounds and
/// only shrinks a little in a pause, so breaths never undo it. The amount of
/// sound needed adapts to the child: a little more than their longest hold
/// so far, between [minSeconds] and [maxSeconds].
class BalloonView extends StatefulWidget {
  const BalloonView({super.key});

  @override
  State<BalloonView> createState() => _BalloonViewState();
}

const minSeconds = 3.0, maxSeconds = 8.0;

/// Seconds of sound a balloon needs for a child whose longest hold is [longestHold].
double balloonSeconds(double longestHold) => (longestHold * 1.1).clamp(minSeconds, maxSeconds);

class _BalloonViewState extends ListeningState<BalloonView> {
  static const colours = [Color(0xFFFF5A6E), Color(0xFF5EC8F2), Color(0xFFFFC857), Color(0xFF8BE07A), Color(0xFFB9A7F5)];

  double _size = 0;
  double _hold = 0;
  double _level = 0;
  double _silence = 0;
  late double _need = balloonSeconds(profile.longestHold);
  bool _floating = false;
  double _rise = 0;
  bool _showNext = false;
  int _colour = 0;

  @override
  void onStarted() => services.sound.say('balloon_intro');

  @override
  void onVoice(VoiceFrame f, double dt) {
    final speaking = services.sound.speaking.value;
    _level = smoothTo(_level, f.voiced ? f.level : 0, 8, dt);
    if (_floating) {
      _rise += dt;
      setState(() {});
      return;
    }
    if (f.voiced) {
      _silence = 0;
      _hold += dt;
      if (_hold > profile.longestHold) profile.longestHold = _hold;
      _size = math.min(1, _size + dt / _need);
      if (_size >= 1) _float();
    } else if (!speaking) {
      _silence += dt;
      // Short gaps between frames are still the same held sound.
      if (_silence > 0.35) _hold = 0;
      _size = math.max(0, _size - dt / _need * 0.25);
      if (_silence > 12) {
        _silence = 0;
        services.sound.say('balloon_intro');
      }
    }
    setState(() {});
  }

  void _float() {
    _floating = true;
    _rise = 0;
    profile.balloons++;
    profile.markDone('balloon');
    services.store.save();
    services.sound.sfx(Sfx.whoosh);
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) services.sound.say('balloon_float');
    });
    Future<void>.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _showNext = true);
    });
  }

  void _again() {
    setState(() {
      _size = 0;
      _hold = 0;
      _floating = _showNext = false;
      _colour = (_colour + 1) % colours.length;
      _need = balloonSeconds(profile.longestHold);
    });
    services.sound.say('balloon_again');
  }

  @override
  void dispose() {
    services.store.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ColoredBox(
      color: SP.night,
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(
          painter: BalloonPainter(
            size: _size,
            rise: _rise,
            wobble: profile.calmMode ? 0 : _level,
            colour: colours[_colour],
          ),
        ),
        SafeArea(
          child: Stack(children: [
            Positioned(
              left: 8,
              bottom: 0,
              child: IgnorePointer(
                child: CharacterView(
                  character: Character.pip,
                  pose: _floating ? 'wave' : 'idle',
                  height: size.height * 0.3,
                  scale: 1 + 0.08 * _level,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: GlowIconButton(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
            ),
            if (_showNext)
              Positioned(
                right: 24,
                top: 0,
                bottom: 0,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  GlowIconButton(icon: Icons.replay_rounded, label: 'Another balloon', size: 104, onTap: _again),
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

/// Soft day sky with clouds and one balloon on a string, growing with
/// [size] (0..1) and floating up with [rise] (seconds since it let go).
class BalloonPainter extends CustomPainter {
  BalloonPainter({required this.size, required this.rise, required this.wobble, required this.colour});

  final double size;
  final double rise;
  final double wobble;
  final Color colour;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7FB2F0), Color(0xFFCFE4FA)],
        ).createShader(r),
    );
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final c in const [Offset(0.18, 0.18), Offset(0.7, 0.12), Offset(0.85, 0.42)]) {
      final o = Offset(c.dx * s.width, c.dy * s.height);
      final u = s.height * 0.05;
      canvas.drawCircle(o, u, cloud);
      canvas.drawCircle(o + Offset(u * 0.9, u * 0.2), u * 0.8, cloud);
      canvas.drawCircle(o - Offset(u * 0.9, -u * 0.2), u * 0.7, cloud);
    }
    // Grass.
    canvas.drawRect(Rect.fromLTWH(0, s.height * 0.86, s.width, s.height * 0.14), Paint()..color = const Color(0xFF8CCB7A));

    final eased = Curves.easeOut.transform(size.clamp(0.0, 1.0));
    final radius = s.height * (0.06 + 0.22 * eased);
    final anchor = Offset(s.width * 0.55, s.height * 0.86);
    final lift = rise <= 0 ? 0.0 : s.height * 1.4 * Curves.easeIn.transform((rise / 2.5).clamp(0.0, 1.0));
    final sway = math.sin(rise * 3) * s.width * 0.03 * (rise > 0 ? 1 : 0);
    final centre = Offset(anchor.dx + sway, anchor.dy - s.height * 0.12 - radius * 1.1 - lift);
    final w = radius * (1 + 0.04 * wobble), h = radius * 1.15 * (1 - 0.03 * wobble);

    // String.
    final knot = centre + Offset(0, h);
    final string = Path()
      ..moveTo(knot.dx, knot.dy)
      ..quadraticBezierTo(knot.dx - 20, knot.dy + s.height * 0.06, knot.dx + (rise > 0 ? 0 : anchor.dx - knot.dx),
          rise > 0 ? knot.dy + s.height * 0.12 : anchor.dy);
    canvas.drawPath(
        string,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = SP.plum);

    final body = Rect.fromCenter(center: centre, width: w * 2, height: h * 2);
    canvas.drawOval(body, Paint()..color = colour);
    canvas.drawOval(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = SP.plum.withValues(alpha: 0.8));
    canvas.drawOval(Rect.fromCenter(center: centre + Offset(-w * 0.38, -h * 0.4), width: w * 0.35, height: h * 0.45),
        Paint()..color = Colors.white.withValues(alpha: 0.45));
    final tie = Path()
      ..moveTo(knot.dx - 8, knot.dy + 8)
      ..lineTo(knot.dx + 8, knot.dy + 8)
      ..lineTo(knot.dx, knot.dy - 2)
      ..close();
    canvas.drawPath(tie, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(covariant BalloonPainter old) =>
      old.size != size || old.rise != rise || old.wobble != wobble || old.colour != colour;
}
