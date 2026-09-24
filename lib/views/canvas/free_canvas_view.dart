import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';
import 'paint_engine.dart';

/// Free Canvas: sing, hum or say "aaah" to paint; fingers paint too.
///
/// Nothing can go wrong here. Every painting is kept: leaving or starting a
/// fresh page saves it to the child's gallery automatically.
class FreeCanvasView extends StatefulWidget {
  const FreeCanvasView({super.key});

  @override
  State<FreeCanvasView> createState() => _FreeCanvasViewState();
}

class _FreeCanvasViewState extends ListeningState<FreeCanvasView> {
  late final PaintEngine _engine = PaintEngine(calm: profile.calmMode);
  final _rand = math.Random();

  // Pip reacts to pitch, Ollie to loudness; smoothed so poses don't flicker.
  double _pitch = 0.5;
  double _level = 0;
  bool _voiced = false;

  // Coaching: praise while the child pauses, never over them.
  double _sinceSound = 99;
  double _sinceTalk = 0;
  double _activeSinceTalk = 0;
  double _idle = 0;
  bool _fingerHinted = false;
  double _avgPitch = 0.5, _avgLevel = 0.5;
  bool _saving = false;

  @override
  void onStarted() {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) services.sound.say('canvas_intro');
    });
  }

  @override
  void onVoice(VoiceFrame f, double dt) {
    _engine.update(dt, f);
    final speaking = services.sound.speaking.value;
    _voiced = f.voiced;
    _level = smoothTo(_level, f.voiced ? f.level : 0, 8, dt);
    if (f.voiced && f.pitched) _pitch = smoothTo(_pitch, f.pitchNorm, 6, dt);

    if (_engine.active) {
      _sinceSound = 0;
      _idle = 0;
      _activeSinceTalk += dt;
      if (f.voiced) {
        _avgPitch = smoothTo(_avgPitch, f.pitched ? f.pitchNorm : _avgPitch, 0.5, dt);
        _avgLevel = smoothTo(_avgLevel, f.level, 0.5, dt);
      }
    } else {
      _sinceSound += dt;
      _idle += dt;
    }
    if (!speaking) _sinceTalk += dt;
    _coach(speaking);
    setState(() {});
  }

  void _coach(bool speaking) {
    if (speaking) return;
    if (!_fingerHinted && _idle > 10 && _sinceTalk > 8) {
      _fingerHinted = true;
      _say('canvas_finger');
      return;
    }
    if (_idle > 35 && _sinceTalk > 30) {
      _say('canvas_intro');
      return;
    }
    // Praise after ~18 s of painting, once the child takes a breath.
    if (_activeSinceTalk > 18 && _sinceSound > 0.8 && _sinceTalk > 12) {
      final String line;
      if (_avgPitch > 0.72) {
        line = 'canvas_high';
      } else if (_avgPitch < 0.28) {
        line = 'canvas_low';
      } else if (_avgLevel > 0.75) {
        line = 'ollie_loud';
      } else if (_avgLevel < 0.25) {
        line = 'ollie_quiet';
      } else {
        line = 'canvas_praise${1 + _rand.nextInt(3)}';
      }
      _say(line);
      if (!profile.calmMode) services.sound.sfx(Sfx.sparkle, volume: 0.35);
    }
  }

  void _say(String id) {
    _sinceTalk = 0;
    _activeSinceTalk = 0;
    services.sound.say(id);
  }

  Future<bool> _savePainting() async {
    if (_engine.painted < 40 || _saving) return false;
    _saving = true;
    try {
      final png = await _engine.exportPng();
      if (png == null) return false;
      await services.store.addPainting(profile, png);
      return true;
    } finally {
      _saving = false;
    }
  }

  Future<void> _freshPage() async {
    await _savePainting();
    _engine.clear();
    services.sound.sfx(Sfx.whoosh);
    _say('canvas_cleared');
  }

  Future<void> _goHome() async {
    final saved = await _savePainting();
    if (!mounted) return;
    // Home says "saved in your gallery": this screen's audio stops as it closes.
    Navigator.pop(context, saved);
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final charH = size.height * 0.26;
    final pipPose = !_voiced ? 'idle' : (_pitch > 0.66 ? 'high' : (_pitch < 0.34 ? 'low' : 'idle'));
    final olliePose = !_voiced ? 'idle' : (_level > 0.7 ? 'loud' : (_level < 0.3 ? 'quiet' : 'idle'));
    final aura = _voiced ? HSVColor.fromAHSV(1, hueForPitch(_pitch), 0.8, 1).toColor() : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scene(
        background: 'bg_canvas',
        child: Stack(children: [
          Positioned.fill(
            child: LayoutBuilder(builder: (context, c) {
              _engine.resize(c.biggest, dpr);
              return GestureDetector(
                onPanStart: (d) => _engine.fingerDown(d.localPosition),
                onPanUpdate: (d) => _engine.fingerMove(d.localPosition),
                onPanEnd: (_) => _engine.fingerUp(),
                onPanCancel: _engine.fingerUp,
                child: Semantics(
                  label: 'Painting canvas. Sing or touch to paint.',
                  child: CustomPaint(painter: _CanvasPainter(_engine), size: c.biggest),
                ),
              );
            }),
          ),
          Positioned(
            left: 8,
            bottom: 0,
            child: IgnorePointer(
              child: CharacterView(
                character: Character.pip,
                pose: pipPose,
                height: charH,
                aura: aura,
                scale: 1 + 0.12 * _level,
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 0,
            child: IgnorePointer(
              child: CharacterView(
                character: Character.ollie,
                pose: olliePose,
                height: charH * 0.9,
                scale: 1 + 0.18 * _level,
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: GlowIconButton(icon: Icons.home_rounded, label: 'Home', onTap: _goHome),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: HoldButton(icon: Icons.auto_awesome_rounded, label: 'New page', onHeld: _freshPage),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(child: IgnorePointer(child: AudioHud(engine: services.voice, micOn: micOn))),
          ),
        ]),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter(this.engine);
  final PaintEngine engine;

  @override
  void paint(Canvas canvas, Size size) => engine.paint(canvas);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
