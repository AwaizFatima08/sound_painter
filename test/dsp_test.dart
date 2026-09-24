import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_painter/core/audio/dsp.dart';
import 'package:sound_painter/core/audio/synth_voice.dart';
import 'package:sound_painter/core/audio/voice_analyzer.dart';

Float32List sine(double hz, {double seconds = 0.1, double amp = 0.3}) {
  final n = (seconds * kSampleRate).round();
  return Float32List.fromList(
      List.generate(n, (i) => amp * math.sin(2 * math.pi * hz * i / kSampleRate)));
}

void main() {
  group('pcm16ToFloat', () {
    test('respects a sliced view offset', () {
      final whole = Uint8List(8);
      ByteData.sublistView(whole)
        ..setInt16(0, 1000, Endian.little)
        ..setInt16(2, -16384, Endian.little)
        ..setInt16(4, 16384, Endian.little);
      final view = Uint8List.sublistView(whole, 2, 6);
      final f = pcm16ToFloat(view);
      expect(f.length, 2);
      expect(f[0], closeTo(-0.5, 1e-6));
      expect(f[1], closeTo(0.5, 1e-6));
    });
  });

  group('YIN pitch', () {
    final yin = YinPitchDetector();
    for (final hz in [110.0, 196.0, 262.0, 330.0, 440.0, 660.0, 900.0]) {
      test('finds ${hz.round()} Hz within 1.5%', () {
        final x = Float32List.sublistView(sine(hz), 0, 1024);
        final p = yin.detect(x);
        expect(p.voiced, isTrue);
        expect(p.hz, closeTo(hz, hz * 0.015));
      });
    }

    test('synthetic child vowel at 300 Hz is not an octave off', () {
      final x = SynthVoice().childVowel(Vowel.a, seconds: 0.2, f0: 300);
      final p = yin.detect(Float32List.sublistView(x, 1000, 2024));
      expect(p.hz, closeTo(300, 9));
    });

    test('noise is unpitched', () {
      final x = SynthVoice().silence(0.1, noise: 0.3);
      expect(yin.detect(Float32List.sublistView(x, 0, 1024)).voiced, isFalse);
    });
  });

  group('vowels', () {
    for (final v in Vowel.values) {
      for (final f0 in [240.0, 300.0, 360.0]) {
        test('classifies synthetic child /${v.letter}/ at ${f0.round()} Hz', () {
          final analyzer = VoiceAnalyzer();
          final frames = analyzer.add(SynthVoice().childVowel(v, f0: f0));
          final votes = <Vowel, int>{};
          for (final fr in frames) {
            if (fr.vowel != null) votes[fr.vowel!] = (votes[fr.vowel!] ?? 0) + 1;
          }
          expect(votes, isNotEmpty);
          final top = votes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
          expect(top, v, reason: 'votes: $votes');
        });
      }
    }

    test('a low adult voice raises the formant scale, a child voice keeps 1.0', () {
      final adult = VowelClassifier();
      final child = VowelClassifier();
      for (var i = 0; i < 200; i++) {
        adult.observePitch(120);
        child.observePitch(300);
      }
      expect(adult.scale, closeTo(1.25, 0.01));
      expect(child.scale, 1.0);
    });

    for (final v in Vowel.values) {
      test('an adult /${v.letter}/ (formants 0.8x, 120 Hz) is recognised', () {
        final (f1, f2) = VowelClassifier.childCentroids[v]!;
        final x = SynthVoice().vowel(seconds: 1.5, f0: 120, f1: f1 * 0.8, f2: f2 * 0.8, f3: 2900);
        final a = VoiceAnalyzer();
        final votes = <Vowel, int>{};
        for (final fr in a.add(x).skip(10)) {
          if (fr.vowel != null) votes[fr.vowel!] = (votes[fr.vowel!] ?? 0) + 1;
        }
        final top = votes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        expect(top, v, reason: 'votes: $votes');
      });
    }
  });

  group('calibration', () {
    const cal = Calibration(noiseRms: 0.005, loudRms: 0.2, lowHz: 200, highHz: 500);

    test('silence maps to level 0 and loud to 1', () {
      expect(cal.level(0.004), 0);
      expect(cal.level(0.2), closeTo(1, 1e-9));
      expect(cal.level(0.05), inExclusiveRange(0, 1));
    });

    test('sensitivity makes soft voices register more', () {
      expect(cal.copyWith(sensitivity: 2).level(0.03), greaterThan(cal.level(0.03)));
    });

    test('pitch maps across the child range', () {
      expect(cal.pitchNorm(150), 0);
      expect(cal.pitchNorm(700), 1);
      expect(cal.pitchNorm(316), closeTo(0.5, 0.05));
    });

    test('a narrow measured range is widened to half an octave', () {
      final c = cal.withMeasured(low: 300, high: 330);
      expect(c.highHz / c.lowHz, closeTo(1.5, 1e-6));
    });

    test('round-trips through JSON', () {
      final c = Calibration.fromJson(cal.toJson());
      expect(c.lowHz, cal.lowHz);
      expect(c.loudRms, cal.loudRms);
    });
  });

  group('analyzer stream', () {
    test('chunked input gives the same frame count as one block', () {
      final x = SynthVoice().childVowel(Vowel.o, seconds: 1);
      final whole = VoiceAnalyzer().add(x).length;
      final a = VoiceAnalyzer();
      var chunked = 0;
      for (var i = 0; i < x.length; i += 333) {
        chunked += a.add(Float32List.sublistView(x, i, math.min(i + 333, x.length))).length;
      }
      expect(chunked, whole);
      expect(whole, (x.length - VoiceAnalyzer.window) ~/ VoiceAnalyzer.hop + 1);
    });

    test('silence is not voiced, a hum is', () {
      final s = SynthVoice();
      final a = VoiceAnalyzer();
      expect(a.add(s.silence(0.5)).any((f) => f.voiced), isFalse);
      final hum = a.add(s.vowel(seconds: 0.5, f0: 250, f1: 400, f2: 1200));
      expect(hum.where((f) => f.voiced).length, greaterThan(hum.length ~/ 2));
      expect(hum.last.pitchHz, closeTo(250, 8));
    });
  });
}
