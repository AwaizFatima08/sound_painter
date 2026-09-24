import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/sound_player.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/listening.dart';

enum _Phase { noise, hello, loud, quiet, high, low, done }

/// Pip's warm-up: measures the room's noise and this child's own loud/quiet
/// and high/low range, so colour and brush size span *their* voice rather
/// than a fixed range (important for children with a narrow range).
///
/// Nothing can fail: a part the child doesn't do is skipped kindly and keeps
/// its default. Takes about a minute.
class WarmupView extends StatefulWidget {
  const WarmupView({super.key, this.next});

  /// Screen to open afterwards (replaces this one); null returns to the
  /// previous screen (a parent redoing the warm-up).
  final Widget? next;

  @override
  State<WarmupView> createState() => _WarmupViewState();
}

class _WarmupViewState extends ListeningState<WarmupView> {
  _Phase _phase = _Phase.noise;
  bool _listening = false;
  double _t = 0;
  double _level = 0;
  double _pitch = 0.5;
  bool _voiced = false;
  final _noise = <double>[];
  final _got = <double>[];
  double? _noiseRms, _loudRms, _quietRms, _lowHz, _highHz;

  static const _need = 25; // ~0.8 s of sound
  static const _prompts = {
    _Phase.loud: 'warm_loud',
    _Phase.quiet: 'warm_quiet',
    _Phase.high: 'warm_high',
    _Phase.low: 'warm_low',
  };

  @override
  void onStarted() {
    if (!micOn) {
      // No microphone: nothing to measure. Carry on with the defaults.
      _leave();
      return;
    }
    // Permissive while measuring, so soft voices still register.
    services.voice.calibration = const Calibration(noiseRms: 0.002, sensitivity: 2);
    _phase = _Phase.noise;
    _listening = true;
    _t = 0;
  }

  @override
  void onVoice(VoiceFrame f, double dt) {
    _level = smoothTo(_level, f.voiced ? f.level : 0, 10, dt);
    _voiced = f.voiced;
    if (f.pitched) _pitch = smoothTo(_pitch, f.pitchNorm, 6, dt);
    if (_listening) {
      _t += dt;
      switch (_phase) {
        case _Phase.noise:
          if (f.rms > 0) _noise.add(f.rms);
          if (_t > 1.2) _endNoise();
        case _Phase.loud || _Phase.quiet:
          if (f.voiced) _got.add(f.rms);
          _checkDone();
        case _Phase.high || _Phase.low:
          if (f.voiced && f.pitched) _got.add(f.pitchHz);
          _checkDone();
        default:
      }
    }
    setState(() {});
  }

  void _endNoise() {
    _listening = false;
    if (_noise.isNotEmpty) {
      final s = [..._noise]..sort();
      _noiseRms = s[s.length ~/ 2];
      services.voice.calibration = Calibration(noiseRms: _noiseRms!, sensitivity: 2);
    }
    _run();
  }

  Future<void> _run() async {
    _phase = _Phase.hello;
    await services.sound.say('pip_hello');
    await _next(_Phase.loud);
  }

  Future<void> _next(_Phase p) async {
    if (!mounted) return;
    setState(() => _phase = p);
    _got.clear();
    await services.sound.say(_prompts[p]!);
    if (!mounted) return;
    _t = 0;
    _listening = true;
  }

  void _checkDone() {
    final enough = _got.length >= _need || (_t > 7 && _got.length >= 8);
    if (!enough && _t < 8) return;
    _listening = false;
    final s = [..._got]..sort();
    double pct(double q) => s[(s.length * q).floor().clamp(0, s.length - 1)];
    if (enough) {
      switch (_phase) {
        case _Phase.loud:
          _loudRms = pct(0.85);
        case _Phase.quiet:
          _quietRms = pct(0.4);
        case _Phase.high:
          _highHz = pct(0.85);
        case _Phase.low:
          _lowHz = pct(0.15);
        default:
      }
      services.sound.sfx(Sfx.chime, volume: 0.4);
    }
    unawaited(_afterPhase(enough));
  }

  Future<void> _afterPhase(bool gotIt) async {
    if (!gotIt) await services.sound.say('warm_skip');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    switch (_phase) {
      case _Phase.loud:
        await _next(_Phase.quiet);
      case _Phase.quiet:
        await _next(_Phase.high);
      case _Phase.high:
        await _next(_Phase.low);
      default:
        await _finish();
    }
  }

  Future<void> _finish() async {
    final p = profile;
    var noise = _noiseRms;
    if (noise != null && _quietRms != null) noise = math.min(noise, _quietRms! / 3);
    p.calibration = p.calibration.withMeasured(noise: noise, loud: _loudRms, low: _lowHz, high: _highHz);
    p.warmedUp = true;
    await services.store.save();
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
    services.sound.sfx(Sfx.tada, volume: 0.5);
    await services.sound.say('warm_done');
    _leave();
  }

  void _leave() {
    if (!mounted) return;
    profile.warmedUp = true;
    services.store.save();
    final next = widget.next;
    if (next == null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(fadeRoute(next));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final h = size.height * 0.55;
    final String pose;
    if (_phase == _Phase.done) {
      pose = 'high';
    } else if (_voiced && (_phase == _Phase.high || (_phase == _Phase.loud && _level > 0.6))) {
      pose = 'high';
    } else if (_voiced && _phase == _Phase.low) {
      pose = 'low';
    } else {
      pose = 'idle';
    }
    final progress = _listening && _phase != _Phase.noise ? (_got.length / _need).clamp(0.0, 1.0) : 0.0;
    final aura = _voiced ? HSVColor.fromAHSV(1, hueForPitch(_pitch), 0.8, 1).toColor() : SP.teal.withValues(alpha: 0.4);

    return PopScope(
      canPop: false,
      child: Scene(
        background: 'bg_warmup',
        child: Stack(children: [
          Center(
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: h * 1.05,
                height: h * 1.05,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  color: SP.teal,
                  backgroundColor: SP.night.withValues(alpha: 0.35),
                  strokeCap: StrokeCap.round,
                ),
              ),
              CharacterView(character: Character.pip, pose: pose, height: h * 0.8, aura: aura, scale: 1 + 0.25 * _level),
            ]),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(child: AudioHud(engine: services.voice, micOn: micOn)),
          ),
        ]),
      ),
    );
  }
}
