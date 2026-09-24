import 'package:flutter/material.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/dsp.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';
import '../../widgets/listening.dart';
import '../../widgets/parent_widgets.dart';

/// For parents and testers: what the app hears right now, using the active
/// child's calibration. Handy for checking a device's microphone, the
/// sensitivity setting, and how vowels are being recognised.
class SoundCheckView extends StatefulWidget {
  const SoundCheckView({super.key});

  @override
  State<SoundCheckView> createState() => _SoundCheckViewState();
}

class _SoundCheckViewState extends ListeningState<SoundCheckView> {
  VoiceFrame _f = VoiceFrame.silent;
  double _peakRms = 0;
  Vowel? _heldVowel;
  double _holdTime = 0;

  @override
  void onStarted() => services.voice.scoreVowels = true;

  @override
  void onVoice(VoiceFrame f, double dt) {
    _f = f;
    _peakRms = f.rms > _peakRms ? f.rms : _peakRms * 0.995;
    if (f.vowel != null) {
      _heldVowel = f.vowel;
      _holdTime = 0;
    } else {
      _holdTime += dt;
      if (_holdTime > 0.6) _heldVowel = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cal = services.voice.calibration;
    final f = _f;
    final scores = f.vowelScores;
    return ParentPage(
      title: 'Sound check',
      onClose: () => Navigator.pop(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Lead(micOn
            ? 'Make sounds near the device. Nothing is recorded.'
            : 'The microphone is not available. Allow it in the grown-ups area first.'),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Loudness',
          icon: Icons.volume_up_rounded,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Meter(value: f.level, color: SP.teal),
            const SizedBox(height: 8),
            Text(
              f.voiced ? 'Heard  ·  level ${(f.level * 100).round()}%' : 'Quiet (below the noise gate)',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Input ${(f.rms * 1000).toStringAsFixed(1)}  ·  gate ${(cal.gateRms * 1000).toStringAsFixed(1)}  ·  '
              'loud ${(cal.loudRms * 1000).toStringAsFixed(0)}  ·  peak ${(_peakRms * 1000).toStringAsFixed(0)}  (×1000 RMS)',
              style: const TextStyle(color: SP.muted, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ]),
        ),
        SectionCard(
          title: 'Pitch',
          icon: Icons.music_note_rounded,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Meter(
              value: f.pitched ? f.pitchNorm : 0,
              color: f.pitched ? HSVColor.fromAHSV(1, hueForPitch(f.pitchNorm), 0.8, 1).toColor() : SP.cardLine,
            ),
            const SizedBox(height: 8),
            Text(
              f.pitched ? '${f.pitchHz.round()} Hz' : (f.voiced ? 'Sound without a clear pitch' : '–'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text('This child\'s range: ${cal.lowHz.round()}–${cal.highHz.round()} Hz',
                style: const TextStyle(color: SP.muted)),
          ]),
        ),
        SectionCard(
          title: 'Vowel',
          icon: Icons.record_voice_over_rounded,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _heldVowel == null ? 'Hold a vowel: aaa (apple), eh (egg), ih (igloo), o (octopus), uh (umbrella)'
                  : 'Sounds like: ${_heldVowel!.letter}  (${_heldVowel!.word})',
              style: TextStyle(fontSize: _heldVowel == null ? 16 : 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final v in Vowel.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 110, child: Text('${v.letter}  ${v.word}')),
                  Expanded(
                    child: _Meter(
                      value: scores == null ? 0 : (1 - (scores[v]! - scores.values.reduce((a, b) => a < b ? a : b)) / 6).clamp(0.0, 1.0),
                      color: v == f.vowel ? SP.teal : SP.lilac,
                      height: 10,
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.value, required this.color, this.height = 18});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(value: value, minHeight: height, color: color, backgroundColor: SP.dusk),
    );
  }
}
