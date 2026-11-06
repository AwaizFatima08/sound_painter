import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';

/// Ollie's Lanterns: Ollie asks for a quiet voice, then a big one, in turn.
/// A held sound lights the next lantern: a quiet sound lights a small
/// lantern, a loud sound a big one.
///
/// Errorless: every sound lights a lantern, whatever Ollie asked for. In
/// Practise level the asked-for loudness lights it faster.
class LanternsView extends StatefulWidget {
  const LanternsView({super.key});

  @override
  State<LanternsView> createState() => _LanternsViewState();
}

class _LanternsViewState extends ListeningState<LanternsView> {
  static const count = 8;

  /// Size of each lit lantern: true = big (loud), false = small (quiet).
  final _lit = <bool>[];
  double _charge = 0;
  double _level = 0;
  double _loudness = 0;
  bool _askLoud = false;
  double _silence = 0;
  bool _done = false;
  bool _showNext = false;

  bool get practise => profile.level == PlayLevel.practise;

  /// Level (0..1) from which this child's sound counts as big.
  late final double loudFrom = profile.calibration.loudSplit;

  @override
  void onStarted() => _intro();

  Future<void> _intro() async {
    await services.sound.say('lantern_intro');
    if (mounted) _ask();
  }

  void _ask() => services.sound.say(_askLoud ? 'lantern_loud' : 'lantern_quiet');

  @override
  void onVoice(VoiceFrame f, double dt) {
    final speaking = services.sound.speaking.value;
    _level = smoothTo(_level, f.voiced ? f.level : 0, 8, dt);
    if (_done) {
      setState(() {});
      return;
    }
    if (f.voiced) {
      _silence = 0;
      // Average loudness of this held sound decides the lantern's size.
      _loudness = _charge == 0 ? f.level : smoothTo(_loudness, f.level, 2, dt);
      final asked = (_askLoud && f.level >= loudFrom) || (!_askLoud && f.level < loudFrom);
      final rate = practise ? (asked ? 0.75 : 0.4) : 0.6;
      _charge = math.min(1, _charge + rate * dt);
      if (_charge >= 1) _light();
    } else if (!speaking) {
      _silence += dt;
      // A pause keeps most of the glow, so short breaths don't undo it.
      _charge = math.max(0, _charge - 0.15 * dt);
      if (_silence > 10) {
        _silence = 0;
        _ask();
      }
    }
    setState(() {});
  }

  void _light() {
    final big = _loudness >= loudFrom;
    _lit.add(big);
    big ? profile.lanternsLoud++ : profile.lanternsQuiet++;
    _charge = 0;
    services.sound.sfx(Sfx.chime, volume: big ? 0.8 : 0.45);
    if (_lit.length == count) {
      _done = true;
      services.store.save();
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) services.sound.say('lantern_all');
      });
      Future<void>.delayed(const Duration(milliseconds: 3400), () {
        if (mounted) setState(() => _showNext = true);
      });
    } else {
      _askLoud = !_askLoud;
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_done) _ask();
      });
    }
  }

  void _again() {
    setState(() {
      _lit.clear();
      _charge = 0;
      _askLoud = false;
      _done = _showNext = false;
    });
    _ask();
  }

  @override
  void dispose() {
    services.store.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final quiet = _level > 0 && _level < loudFrom;
    return ColoredBox(
      color: SP.night,
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: LanternsPainter(lit: _lit, count: count, charge: _charge, chargeBig: _loudness >= loudFrom)),
        SafeArea(
          child: Stack(children: [
            Positioned(
              left: 8,
              bottom: 0,
              child: IgnorePointer(
                child: CharacterView(
                  character: Character.ollie,
                  pose: _level == 0 ? 'idle' : (quiet ? 'quiet' : 'loud'),
                  height: size.height * 0.36,
                  scale: 1 + 0.08 * _level,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: GlowIconButton(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GlowIconButton(
                  icon: Icons.hearing_rounded, label: 'Hear Ollie again', color: SP.amber, onTap: _done ? null : _ask),
            ),
            Positioned(
              right: 20,
              bottom: 16,
              child: Semantics(
                label: _askLoud ? 'Ollie asks for a big voice' : 'Ollie asks for a quiet voice',
                child: Icon(_askLoud ? Icons.campaign_rounded : Icons.volume_down_rounded,
                    color: SP.cream.withValues(alpha: 0.85), size: 56),
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

/// A night sky with a string of paper lanterns. Lit lanterns glow (big or
/// small); the next one brightens as the child holds a sound.
class LanternsPainter extends CustomPainter {
  LanternsPainter({required this.lit, required this.count, required this.charge, required this.chargeBig});

  final List<bool> lit;
  final int count;
  final double charge;
  final bool chargeBig;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E0A26), Color(0xFF241A4D), Color(0xFF3A2D6E)],
        ).createShader(r),
    );
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.45);
    final rand = math.Random(7);
    for (var i = 0; i < 50; i++) {
      canvas.drawCircle(Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height * 0.6), 1.1, dot);
    }

    // The string, sagging between the two top corners.
    final left = size.width * 0.2, right = size.width * 0.96;
    double stringY(double x) {
      final t = (x - left) / (right - left);
      return size.height * (0.16 + 0.12 * math.sin(t * math.pi));
    }

    final string = Path()..moveTo(left, stringY(left));
    for (var x = left; x <= right; x += 8) {
      string.lineTo(x, stringY(x));
    }
    canvas.drawPath(
        string,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = SP.muted);

    for (var i = 0; i < count; i++) {
      final x = left + (right - left) * (i + 0.5) / count;
      final top = stringY(x);
      final unit = size.height * 0.11;
      if (i < lit.length) {
        _lantern(canvas, Offset(x, top), unit * (lit[i] ? 1.25 : 0.8), 1);
      } else if (i == lit.length) {
        _lantern(canvas, Offset(x, top), unit * (charge > 0 && chargeBig ? 1.1 : 0.9), charge);
      } else {
        _lantern(canvas, Offset(x, top), unit * 0.9, 0);
      }
    }
  }

  /// One lantern hanging from [hook]; [glow] 0 = dark, 1 = fully lit.
  void _lantern(Canvas canvas, Offset hook, double h, double glow) {
    final w = h * 0.75;
    final body = Rect.fromCenter(center: hook + Offset(0, h * 0.25 + h / 2), width: w, height: h);
    canvas.drawLine(hook, Offset(hook.dx, body.top), Paint()..color = SP.muted..strokeWidth = 2);
    if (glow > 0) {
      canvas.drawCircle(
          body.center,
          h * (0.6 + 0.5 * glow),
          Paint()
            ..color = const Color(0xFFFFB347).withValues(alpha: 0.45 * glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.35));
    }
    final dark = const Color(0xFF4A3A6E), bright = const Color(0xFFFF9A3C);
    canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(w * 0.45)), Paint()..color = Color.lerp(dark, bright, glow)!);
    if (glow > 0) {
      canvas.drawOval(Rect.fromCenter(center: body.center, width: w * 0.45, height: h * 0.5),
          Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: glow));
    }
    final rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = SP.plum.withValues(alpha: 0.6);
    for (var k = 1; k < 4; k++) {
      final y = body.top + body.height * k / 4;
      canvas.drawLine(Offset(body.left + w * 0.08, y), Offset(body.right - w * 0.08, y), rib);
    }
    final cap = Paint()..color = SP.plum;
    canvas.drawRect(Rect.fromCenter(center: Offset(body.center.dx, body.top), width: w * 0.5, height: h * 0.08), cap);
    canvas.drawRect(Rect.fromCenter(center: Offset(body.center.dx, body.bottom), width: w * 0.5, height: h * 0.08), cap);
  }

  @override
  bool shouldRepaint(covariant LanternsPainter old) => true;
}
