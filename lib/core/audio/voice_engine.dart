import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_input.dart';
import 'sound_player.dart';
import 'voice_analyzer.dart';

/// Owns the microphone while a listening screen is open.
///
/// The mic runs only on screens that need it (warm-up, Free Canvas, a Phonics
/// Safari picture) and stops when they close. Samples are analysed on the fly
/// and dropped: nothing is recorded or stored.
class VoiceEngine {
  VoiceEngine({required this.sound, AudioInput Function()? inputFactory})
      : _inputFactory = inputFactory ?? _defaultInput;

  /// Build with `--dart-define=SP_SYNTH_VOICE=true` to drive the app from a
  /// synthetic voice (emulator, screenshots, demos).
  static const synthVoice = bool.fromEnvironment('SP_SYNTH_VOICE');

  static AudioInput _defaultInput() => synthVoice ? SynthInput() : MicInput();

  final SoundPlayer sound;
  final AudioInput Function() _inputFactory;

  /// Latest analysis; silent while a prompt is speaking.
  final frame = ValueNotifier<VoiceFrame>(VoiceFrame.silent);

  /// Recent levels (0..1) and hues for the live HUD, newest last.
  final history = <(double, double)>[];
  static const historyLength = 28;

  final _analyzer = VoiceAnalyzer();
  AudioInput? _input;
  StreamSubscription<Float32List>? _sub;
  bool _running = false;

  bool get running => _running;
  VoiceAnalyzer get analyzer => _analyzer;

  set calibration(Calibration c) => _analyzer.calibration = c;

  /// Turn on vowel recognition (Phonics Safari, Sound check).
  set scoreVowels(bool on) => _analyzer.scoreVowels = on;
  Calibration get calibration => _analyzer.calibration;

  /// Starts listening. Returns false when the mic isn't available (no
  /// permission); screens then fall back to finger painting.
  Future<bool> start() async {
    if (_running) return true;
    final input = _inputFactory();
    if (input is MicInput && !await MicInput.granted()) return false;
    try {
      final stream = await input.start();
      _input = input;
      _running = true;
      _sub = stream.listen(_onSamples);
      return true;
    } catch (e) {
      debugPrint('mic start failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    _running = false;
    _analyzer.scoreVowels = false;
    await _sub?.cancel();
    _sub = null;
    await _input?.stop();
    _input = null;
    history.clear();
    frame.value = VoiceFrame.silent;
  }

  /// Feeds samples directly (used by unit tests).
  @visibleForTesting
  void feed(Float32List samples) => _onSamples(samples);

  void _onSamples(Float32List samples) {
    final frames = _analyzer.add(samples);
    if (frames.isEmpty) return;
    final muted = sound.speaking.value;
    for (final f in frames) {
      final shown = muted ? VoiceFrame.silent : f;
      history.add((shown.level, hueForPitch(shown.pitchNorm)));
      if (history.length > historyLength) history.removeAt(0);
      frame.value = shown;
    }
  }
}
