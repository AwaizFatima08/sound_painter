import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_painter/core/audio/dsp.dart';
import 'package:sound_painter/core/audio/voice_analyzer.dart';

Float32List readWav16k(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(b);
  final rate = d.getUint32(24, Endian.little);
  var off = 12;
  while (String.fromCharCodes(b.sublist(off, off + 4)) != 'data') {
    off += 8 + d.getUint32(off + 4, Endian.little);
  }
  final n = d.getUint32(off + 4, Endian.little) ~/ 2;
  final src = Float32List(n);
  for (var i = 0; i < n; i++) {
    src[i] = d.getInt16(off + 8 + i * 2, Endian.little) / 32768;
  }
  final outN = (n * kSampleRate / rate).floor();
  final out = Float32List(outN);
  for (var i = 0; i < outN; i++) {
    final x = i * rate / kSampleRate;
    final j = x.floor();
    final f = x - j;
    out[i] = j + 1 < n ? src[j] * (1 - f) + src[j + 1] * f : src[j];
  }
  return out;
}

/// Real (adult, Gemini TTS) speech: each of Aria's lines holds its target
/// vowel ("aaa... apple"). Recognition on real voices is approximate; these
/// guard the vowels it already gets right (/a/, /i/, /u/). /e/ and /o/ need
/// tuning with real children's recordings from the tester pool (see
/// docs/testing.md).
void main() {
  for (final v in [Vowel.a, Vowel.i, Vowel.u]) {
    test('real voice: /${v.letter}/ is the most-heard vowel in Aria\'s ${v.word} line', () {
      final votes = <Vowel, int>{};
      for (final f in (VoiceAnalyzer()..scoreVowels = true).add(readWav16k('art/voice/aria_${v.name}.wav'))) {
        if (f.vowel != null) votes[f.vowel!] = (votes[f.vowel!] ?? 0) + 1;
      }
      final top = votes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      expect(top, v, reason: 'votes: $votes');
    });
  }
}
